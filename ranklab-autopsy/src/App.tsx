import { useMemo, useState } from 'react';
import {
  getCatalog,
  getInjectableCategory,
  getUsers,
} from './engine/catalog';
import { runAutopsyPipeline } from './engine/pipeline';
import { runAbSimulation } from './engine/abSimulator';
import { DatasetMode, SessionEvent } from './engine/types';
import { ControlSidebar } from './components/ControlSidebar';
import { RecommendationsPanel } from './components/RecommendationsPanel';
import { FrontierPanel } from './components/FrontierPanel';
import { BiasAutopsyPanel } from './components/BiasAutopsyPanel';
import { AbVerdictPanel } from './components/AbVerdictPanel';

function buildInitialSession(
  dataset: DatasetMode,
  userId: string,
  injectedCount: number
): SessionEvent[] {
  const catalog = getCatalog(dataset);
  const users = getUsers(dataset);
  const user = users.find((u) => u.id === userId) ?? users[0];
  const injectable = getInjectableCategory(dataset);

  // 1-2 organic seed clicks matching user's historical taste
  const organicItems = catalog
    .filter(
      (item) =>
        item.category === user.sessionSeedCategory &&
        !user.historyItemIds.includes(item.id)
    )
    .slice(0, 2);

  const events: SessionEvent[] = organicItems.map((item, idx) => ({
    itemId: item.id,
    title: item.title,
    category: item.category,
    tags: item.tags,
    stepIndex: idx,
    intentType: 'organic',
  }));

  // Plus injected intent clicks (e.g. Sci-Fi or Studio Audio)
  for (let i = 0; i < injectedCount; i++) {
    const item = injectable.items[i % injectable.items.length];
    events.push({
      itemId: item.id,
      title: item.title,
      category: item.category,
      tags: item.tags,
      stepIndex: events.length,
      intentType: 'injected',
    });
  }

  return events;
}

export default function App() {
  const [dataset, setDataset] = useState<DatasetMode>('movielens');
  const users = useMemo(() => getUsers(dataset), [dataset]);
  const catalog = useMemo(() => getCatalog(dataset), [dataset]);
  const injectable = useMemo(() => getInjectableCategory(dataset), [dataset]);

  const [selectedUserId, setSelectedUserId] = useState<string>('u_noir');
  const [injectedCount, setInjectedCount] = useState<number>(2);
  const [removedOrganicIds, setRemovedOrganicIds] = useState<string[]>([]);

  const [efSearch, setEfSearch] = useState<number>(64);
  const [activeRanker, setActiveRanker] = useState<'ipw' | 'naive'>('ipw');
  const [eta, setEta] = useState<number>(0.85);
  const [mmrLambda, setMmrLambda] = useState<number>(0.78);
  const [selectedSlotItemId, setSelectedSlotItemId] = useState<string | null>(null);
  const [simSeed, setSimSeed] = useState<number>(20261118);
  const [srmBugActive, setSrmBugActive] = useState<boolean>(false);

  const sessionEvents = useMemo(() => {
    const base = buildInitialSession(dataset, selectedUserId, injectedCount);
    if (removedOrganicIds.length === 0) return base;
    const removedSet = new Set(removedOrganicIds);
    return base.filter(
      (ev) => ev.intentType !== 'organic' || !removedSet.has(ev.itemId)
    );
  }, [dataset, selectedUserId, injectedCount, removedOrganicIds]);

  const activeUser = useMemo(
    () => users.find((u) => u.id === selectedUserId) ?? users[0],
    [users, selectedUserId]
  );

  const autopsy = useMemo(
    () =>
      runAutopsyPipeline({
        user: activeUser,
        sessionEvents,
        catalog,
        efSearch,
        activeRanker,
        eta,
        mmrLambda,
      }),
    [activeUser, sessionEvents, catalog, efSearch, activeRanker, eta, mmrLambda]
  );

  const abSummary = useMemo(
    () =>
      runAbSimulation({
        dataset,
        autopsy,
        eta,
        seed: simSeed,
        srmBugActive,
      }),
    [dataset, autopsy, eta, simSeed, srmBugActive]
  );

  const handleChangeDataset = (mode: DatasetMode) => {
    setDataset(mode);
    const nextUsers = getUsers(mode);
    setSelectedUserId(nextUsers[0].id);
    setInjectedCount(2);
    setRemovedOrganicIds([]);
    setSelectedSlotItemId(null);
  };

  const handleSelectUser = (userId: string) => {
    setSelectedUserId(userId);
    setRemovedOrganicIds([]);
    setSelectedSlotItemId(null);
  };

  const handleSetInjectedCount = (count: number) => {
    setInjectedCount(count);
  };

  const handleRemoveSessionEvent = (stepIndex: number) => {
    const target = sessionEvents.find((ev) => ev.stepIndex === stepIndex);
    if (!target) return;
    if (target.intentType === 'injected') {
      setInjectedCount((c) => Math.max(0, c - 1));
    } else {
      setRemovedOrganicIds((prev) =>
        prev.includes(target.itemId) ? prev : [...prev, target.itemId]
      );
    }
  };

  return (
    <div className="min-h-screen bg-[#F8F9FA] text-slate-900 flex flex-col">
      {/* Top Bar Contract: strictly 3 zones separated by gap-8 */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-xs border-b border-slate-200">
        <div className="max-w-[1440px] mx-auto px-4 sm:px-6 h-14 flex items-center justify-between gap-8">
          {/* Zone 1: Single-element wordmark */}
          <a
            href="#recommendations"
            className="font-display text-lg font-bold tracking-tight text-slate-900 whitespace-nowrap shrink-0"
          >
            RankLab Autopsy
          </a>

          {/* Zone 2: 4 single-line navigation links */}
          <nav
            aria-label="Diagnostic sections"
            className="hidden md:flex items-center gap-6 text-sm font-medium text-slate-600"
          >
            <a
              href="#recommendations"
              className="hover:text-slate-900 hover:underline underline-offset-4 whitespace-nowrap shrink-0 transition-colors"
            >
              Recommendations
            </a>
            <a
              href="#frontier"
              className="hover:text-slate-900 hover:underline underline-offset-4 whitespace-nowrap shrink-0 transition-colors"
            >
              Recall Frontier
            </a>
            <a
              href="#autopsy"
              className="hover:text-slate-900 hover:underline underline-offset-4 whitespace-nowrap shrink-0 transition-colors"
            >
              Bias Autopsy
            </a>
            <a
              href="#verdict"
              className="hover:text-slate-900 hover:underline underline-offset-4 whitespace-nowrap shrink-0 transition-colors"
            >
              A/B Verdict
            </a>
          </nav>

          {/* Zone 3: 1 primary action */}
          <div className="shrink-0">
            <button
              type="button"
              onClick={() => setSimSeed((s) => s + 17)}
              className="px-4 py-2 text-xs font-medium text-white bg-blue-700 rounded-md hover:bg-blue-800 whitespace-nowrap shrink-0 transition-colors focus-visible:outline-2 focus-visible:outline-blue-600"
            >
              Run Simulation
            </button>
          </div>
        </div>
      </header>

      {/* Main Workspace */}
      <main className="max-w-[1440px] w-full mx-auto px-4 sm:px-6 py-6 flex-1">
        {/* Compact Intro Strip */}
        <div className="mb-6 flex flex-wrap items-baseline justify-between gap-4 border-b border-slate-200 pb-4">
          <div>
            <h1 className="font-display text-2xl font-bold text-slate-900 tracking-tight text-balance">
              Recommender Retrieval, Debiasing &amp; Simulated A/B Autopsy
            </h1>
            <p className="text-sm text-slate-600 mt-1 max-w-3xl">
              Inspect how two-tower HNSW, BM25 tags, and co-visitation fuse via RRF,
              how the learned GRU gate shifts from long-term taste to live session
              intent, and how IPW debiasing outperforms a position-leaking ranker under
              known ground truth.
            </p>
          </div>
          <div className="text-xs font-mono text-slate-500 tabular-nums whitespace-nowrap">
            Two-Tower + GRU → RRF → LambdaRank + MMR → Click Simulator
          </div>
        </div>

        <div className="flex flex-col lg:flex-row items-start gap-6">
          <ControlSidebar
            dataset={dataset}
            onChangeDataset={handleChangeDataset}
            users={users}
            selectedUserId={selectedUserId}
            onSelectUser={handleSelectUser}
            injectableLabel={injectable.label}
            injectedCount={injectedCount}
            onSetInjectedCount={handleSetInjectedCount}
            sessionEvents={sessionEvents}
            onRemoveSessionEvent={handleRemoveSessionEvent}
            autopsy={autopsy}
            efSearch={efSearch}
            onSelectEf={setEfSearch}
            eta={eta}
            onChangeEta={setEta}
            mmrLambda={mmrLambda}
            onChangeMmrLambda={setMmrLambda}
          />

          {/* 4-Panel Diagnostic Canvas */}
          <div className="flex-1 min-w-0 w-full space-y-6">
            {/* Panel 1: Recommendations with Provenance */}
            <RecommendationsPanel
              autopsy={autopsy}
              dataset={dataset}
              efSearch={efSearch}
              selectedSlotItemId={selectedSlotItemId}
              onSelectItem={setSelectedSlotItemId}
              onSetRanker={setActiveRanker}
            />

            {/* Panel 2 & Panel 3 side-by-side on wide screens */}
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 items-stretch">
              <FrontierPanel
                autopsy={autopsy}
                efSearch={efSearch}
                onSelectEf={setEfSearch}
              />
              <BiasAutopsyPanel
                autopsy={autopsy}
                eta={eta}
                selectedSlotItemId={selectedSlotItemId}
              />
            </div>

            {/* Panel 4: Simulated A/B Verdict & Novelty Decay */}
            <AbVerdictPanel
              abSummary={abSummary}
              srmBugActive={srmBugActive}
              onToggleSrmBug={() => setSrmBugActive((v) => !v)}
              onReseedSimulation={() => setSimSeed((s) => s + 17)}
            />
          </div>
        </div>
      </main>
    </div>
  );
}
