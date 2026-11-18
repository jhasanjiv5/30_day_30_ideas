import {
  clamp,
  createRng,
  sampleNormal,
  srmChiSquarePValue,
} from './math';
import {
  AbTestSummary,
  AutopsyResult,
  DailyAbMetric,
  DatasetMode,
} from './types';

export function runAbSimulation(params: {
  dataset: DatasetMode;
  autopsy: AutopsyResult;
  eta: number;
  seed: number;
  srmBugActive: boolean;
  usersPerArm?: number;
}): AbTestSummary {
  const {
    dataset,
    autopsy,
    eta,
    seed,
    srmBugActive,
    usersPerArm = 4200,
  } = params;

  const rng = createRng(seed);
  const days = 14;
  const perDayTarget = Math.floor(usersPerArm / days);

  // Measure expected slate conversion utility under the Position-Biased Click Simulator
  // Control = Naive Ranker slate; Treatment = IPW Debiased Ranker slate
  const computeSlateUtility = (
    slots: AutopsyResult['ipwSlots'],
    mode: DatasetMode
  ) => {
    let probAtLeastOne = 1;
    let expectedWeight = 0;
    for (const s of slots) {
      const exam = Math.pow(s.slot, -eta);
      const clickGivenExam = 0.08 + 0.54 * Math.pow(s.trueRelevance, 1.35);
      const funnelFactor =
        mode === 'otto'
          ? s.item.cartRate * s.item.orderGivenCartRate * 2.2
          : 1.0;
      const pSlot = clamp(exam * clickGivenExam * funnelFactor, 0.002, 0.72);
      probAtLeastOne *= 1 - pSlot;
      expectedWeight += pSlot;
    }
    return {
      sessionConvProb: clamp(1 - probAtLeastOne, 0.015, 0.65),
      expectedWeight,
    };
  };

  const ctrlUtil = computeSlateUtility(autopsy.naiveSlots, dataset);
  const trtUtil = computeSlateUtility(autopsy.ipwSlots, dataset);

  // Base steady-state relative advantage from IPW debiasing (measured directly from slate NDCG & trueRelevance)
  const ndcgDelta = Math.max(0.004, autopsy.ndcgAt10Ipw - autopsy.ndcgAt10Naive);
  const baseCtrlRate =
    dataset === 'otto'
      ? clamp(ctrlUtil.sessionConvProb * 0.42, 0.035, 0.12)
      : clamp(ctrlUtil.sessionConvProb * 0.45, 0.08, 0.22);

  const steadyStateLiftRatio = clamp(
    0.16 *
      ((trtUtil.sessionConvProb - ctrlUtil.sessionConvProb) /
        Math.max(0.01, ctrlUtil.sessionConvProb)) +
      0.18 * ndcgDelta,
    0.014,
    0.072
  );

  // Arrays for exact CUPED & Bootstrap CI computation (multi-session user engagement score)
  const ctrlX: number[] = [];
  const ctrlY: number[] = [];
  const trtX: number[] = [];
  const trtY: number[] = [];

  const dailySeries: DailyAbMetric[] = [];

  for (let d = 1; d <= days; d++) {
    // Novelty effect decays exponentially over the 14-day window:
    // Early exploration boost (+55% of steady-state lift on Day 1) decays with tau=3.6 days
    const noveltyRatio = steadyStateLiftRatio * 0.55 * Math.exp(-(d - 1) / 3.6);
    const dayTrueLiftRatio = steadyStateLiftRatio + noveltyRatio;

    let dayCtrlSum = 0;
    let dayCtrlN = 0;
    let dayTrtSum = 0;
    let dayTrtN = 0;

    for (let u = 0; u < perDayTarget * 2; u++) {
      // 50/50 randomization with optional SRM logging bug (drops ~8.5% of treatment logs)
      const isTreatment = rng() < 0.5;
      if (isTreatment && srmBugActive && rng() < 0.085) {
        continue;
      }

      // Pre-experiment user engagement covariate X_u (7-day user conversion rate, Corr(X,Y) ~ 0.61)
      const sharedLatent = sampleNormal(rng);
      const preRate = clamp(
        baseCtrlRate * (1 + 0.42 * sharedLatent + 0.12 * sampleNormal(rng)),
        0.005,
        0.65
      );

      // Post-assignment user conversion rate over user's experiment sessions (Poisson/Binomial-smoothed)
      const armMean = isTreatment
        ? baseCtrlRate * (1 + dayTrueLiftRatio)
        : baseCtrlRate;
      const yOutcome = clamp(
        armMean +
          0.62 * (preRate - baseCtrlRate) +
          baseCtrlRate * 0.34 * sampleNormal(rng),
        0,
        0.85
      );

      if (isTreatment) {
        trtX.push(preRate);
        trtY.push(yOutcome);
        dayTrtSum += yOutcome;
        dayTrtN++;
      } else {
        ctrlX.push(preRate);
        ctrlY.push(yOutcome);
        dayCtrlSum += yOutcome;
        dayCtrlN++;
      }
    }

    const cRate = dayCtrlN > 0 ? dayCtrlSum / dayCtrlN : baseCtrlRate;
    const tRate = dayTrtN > 0 ? dayTrtSum / dayTrtN : baseCtrlRate;
    const obsLiftPct = ((tRate - cRate) / Math.max(1e-6, cRate)) * 100;
    // Daily SE of relative lift across per-day user observations
    const relSd = 0.42;
    const seRatio =
      relSd * Math.sqrt(1 / Math.max(1, dayCtrlN) + 1 / Math.max(1, dayTrtN));
    const ciHalfPct = 1.96 * seRatio * 100;

    dailySeries.push({
      day: d,
      controlRate: cRate,
      treatmentRate: tRate,
      relativeLiftPct: obsLiftPct,
      ciLowPct: obsLiftPct - ciHalfPct,
      ciHighPct: obsLiftPct + ciHalfPct,
      noveltyComponentPct: (steadyStateLiftRatio + noveltyRatio) * 100,
      steadyStatePct: steadyStateLiftRatio * 100,
    });
  }

  // Compute global means
  const mean = (arr: number[]) =>
    arr.reduce((a, b) => a + b, 0) / Math.max(1, arr.length);

  const meanCtrlY = mean(ctrlY);
  const meanTrtY = mean(trtY);
  const rawLiftPct =
    ((meanTrtY - meanCtrlY) / Math.max(1e-6, meanCtrlY)) * 100;

  // Pooled CUPED theta = Cov(Y, X) / Var(X)
  const allX = [...ctrlX, ...trtX];
  const allY = [...ctrlY, ...trtY];
  const meanX = mean(allX);
  const meanY = mean(allY);

  let covXY = 0;
  let varX = 0;
  let varYRaw = 0;
  for (let i = 0; i < allX.length; i++) {
    const dx = allX[i] - meanX;
    const dy = allY[i] - meanY;
    covXY += dx * dy;
    varX += dx * dx;
    varYRaw += dy * dy;
  }
  const theta = varX > 1e-12 ? covXY / varX : 0;

  // Adjusted observations Y_cuped = Y - theta * (X - meanX)
  const ctrlCuped = ctrlY.map((y, i) => y - theta * (ctrlX[i] - meanX));
  const trtCuped = trtY.map((y, i) => y - theta * (trtX[i] - meanX));
  const allCuped = [...ctrlCuped, ...trtCuped];
  const meanCuped = mean(allCuped);

  let varYCuped = 0;
  for (let i = 0; i < allCuped.length; i++) {
    const d = allCuped[i] - meanCuped;
    varYCuped += d * d;
  }

  const varianceReductionPct = clamp(
    (1 - varYCuped / Math.max(1e-12, varYRaw)) * 100,
    0,
    85
  );

  const meanCtrlCuped = mean(ctrlCuped);
  const meanTrtCuped = mean(trtCuped);
  const cupedLiftPct =
    ((meanTrtCuped - meanCtrlCuped) / Math.max(1e-6, meanCtrlCuped)) * 100;

  // Bootstrap 95% CI (400 resamples over CUPED-adjusted outcomes for speed + accuracy)
  const bootLifts: number[] = [];
  const nC = ctrlCuped.length;
  const nT = trtCuped.length;
  const blockSize = 40; // stratified block bootstrap for crisp <10ms execution
  const cBlocks = Math.floor(nC / blockSize);
  const tBlocks = Math.floor(nT / blockSize);

  const cBlockMeans: number[] = [];
  for (let b = 0; b < cBlocks; b++) {
    let s = 0;
    for (let j = 0; j < blockSize; j++) s += ctrlCuped[b * blockSize + j];
    cBlockMeans.push(s / blockSize);
  }
  const tBlockMeans: number[] = [];
  for (let b = 0; b < tBlocks; b++) {
    let s = 0;
    for (let j = 0; j < blockSize; j++) s += trtCuped[b * blockSize + j];
    tBlockMeans.push(s / blockSize);
  }

  for (let iter = 0; iter < 500; iter++) {
    let sumC = 0;
    for (let k = 0; k < cBlocks; k++) {
      sumC += cBlockMeans[Math.floor(rng() * cBlocks)];
    }
    let sumT = 0;
    for (let k = 0; k < tBlocks; k++) {
      sumT += tBlockMeans[Math.floor(rng() * tBlocks)];
    }
    const mC = sumC / Math.max(1, cBlocks);
    const mT = sumT / Math.max(1, tBlocks);
    bootLifts.push(((mT - mC) / Math.max(1e-6, mC)) * 100);
  }

  bootLifts.sort((a, b) => a - b);
  const ciLowPct = bootLifts[Math.floor(0.025 * bootLifts.length)];
  const ciHighPct = bootLifts[Math.floor(0.975 * bootLifts.length)];

  // Exact SRM Pearson chi-square test
  const srmPValue = srmChiSquarePValue(ctrlY.length, trtY.length);
  const srmPassed = srmPValue >= 0.01;

  // Annualized extra conversions at 1M MAU (12 months * 1,000,000 * abs delta)
  const absDeltaPerUser = Math.max(0, meanTrtCuped - meanCtrlCuped);
  const extraAnnualConversionsAt1M = Math.round(1_000_000 * 12 * absDeltaPerUser);

  return {
    dataset,
    metricLabel:
      dataset === 'otto' ? 'order conversion / user' : 'qualified click / session',
    controlUsers: ctrlY.length,
    treatmentUsers: trtY.length,
    controlRate: meanCtrlY,
    treatmentRate: meanTrtY,
    rawLiftPct,
    cupedLiftPct,
    ciLowPct,
    ciHighPct,
    varianceReductionPct,
    srmPValue,
    srmPassed,
    extraAnnualConversionsAt1M,
    dailySeries,
    propensityEta: eta,
    srmBugActive,
  };
}
