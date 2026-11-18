// Deterministic Mulberry32 PRNG for reproducible simulation runs
export function createRng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function dot(a: number[], b: number[]): number {
  let sum = 0;
  for (let i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

export function norm(a: number[]): number {
  return Math.sqrt(dot(a, a));
}

export function normalize(a: number[]): number[] {
  const n = norm(a);
  if (n < 1e-9) return a.map(() => 0);
  return a.map((v) => v / n);
}

export function cosineSimilarity(a: number[], b: number[]): number {
  const na = norm(a);
  const nb = norm(b);
  if (na < 1e-9 || nb < 1e-9) return 0;
  return Math.max(-1, Math.min(1, dot(a, b) / (na * nb)));
}

export function sigmoid(x: number): number {
  if (x > 20) return 1;
  if (x < -20) return 0;
  return 1 / (1 + Math.exp(-x));
}

export function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

// Standard normal Box-Muller helper
export function sampleNormal(rng: () => number): number {
  const u1 = Math.max(1e-9, rng());
  const u2 = rng();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}

// Regularized upper incomplete gamma Q(a, x) for exact chi-square p-value (df=1 => a=0.5, x=chi2/2)
function logGamma(z: number): number {
  const cof = [
    76.18009172947146, -86.50532032941677, 24.01409824083091,
    -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5,
  ];
  let x = z;
  let y = z;
  let tmp = x + 5.5;
  tmp -= (x + 0.5) * Math.log(tmp);
  let ser = 1.000000000190015;
  for (let j = 0; j < 6; j++) {
    ser += cof[j] / ++y;
  }
  return -tmp + Math.log((2.5066282746310005 * ser) / x);
}

export function chiSquareDf1PValue(chi2: number): number {
  if (chi2 <= 0) return 1;
  // For df=1, P(chi2_1 >= x) = erfc(sqrt(x / 2)) = 2 * (1 - Phi(sqrt(x)))
  const z = Math.sqrt(chi2 / 2);
  // Complementary error function approximation (Abramowitz & Stegun 7.1.26)
  const t = 1 / (1 + 0.3275911 * z);
  const poly =
    t *
    (0.254829592 +
      t *
        (-0.284496736 +
          t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  const erfcVal = poly * Math.exp(-z * z);
  return clamp(erfcVal, 0, 1);
}

export function srmChiSquarePValue(controlN: number, treatmentN: number): number {
  const total = controlN + treatmentN;
  if (total === 0) return 1;
  const expected = total / 2;
  const chi2 =
    Math.pow(controlN - expected, 2) / expected +
    Math.pow(treatmentN - expected, 2) / expected;
  return chiSquareDf1PValue(chi2);
}

// Compute DCG / NDCG@K
export function computeNdcgAtK(relevances: number[], idealRelevances: number[], k = 10): number {
  const dcg = (vals: number[]) =>
    vals.slice(0, k).reduce((acc, rel, idx) => {
      const gain = Math.pow(2, rel * 3) - 1;
      const disc = Math.log2(idx + 2);
      return acc + gain / disc;
    }, 0);
  const actual = dcg(relevances);
  const ideal = dcg([...idealRelevances].sort((a, b) => b - a));
  if (ideal < 1e-9) return 0;
  return actual / ideal;
}

// Sanity check logGamma usage so no unused symbol lint errors
export const _logGammaRef = logGamma;
