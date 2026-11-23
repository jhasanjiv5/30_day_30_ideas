import { useCallback, useEffect, useState } from 'react';
import { AuthModal } from './components/AuthModal.tsx';
import { JobProgressScreen } from './components/JobProgressScreen.tsx';
import { LibraryScreen } from './components/LibraryScreen.tsx';
import { NewVideoScreen } from './components/NewVideoScreen.tsx';
import { PlayerWorkspace } from './components/PlayerWorkspace.tsx';
import { SettingsScreen } from './components/SettingsScreen.tsx';
import { TopBar } from './components/TopBar.tsx';
import {
  ActiveScreen,
  AuditLogEntry,
  DocumentModel,
  JobRecord,
  JobStageName,
  LanguageInfo,
  LibraryItem,
  ResearchNote,
  ResearchSketch,
  VideoArtifact,
  WorkspaceSettings,
} from './types.ts';

export default function App() {
  const [activeScreen, setActiveScreen] = useState<ActiveScreen>('library');
  const [authToken, setAuthToken] = useState<string | null>(null);
  const [userEmail, setUserEmail] = useState('researcher@drishya.local');
  const [authMethod, setAuthMethod] = useState('workspace');
  const [authModalOpen, setAuthModalOpen] = useState(false);

  const [libraryItems, setLibraryItems] = useState<LibraryItem[]>([]);
  const [libraryLoading, setLibraryLoading] = useState(true);
  const [languages, setLanguages] = useState<LanguageInfo[]>([]);
  const [settings, setSettings] = useState<WorkspaceSettings | null>(null);
  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>([]);
  const [jobs, setJobs] = useState<JobRecord[]>([]);
  const [selectedJobId, setSelectedJobId] = useState<string | null>(null);

  const [activePlayerData, setActivePlayerData] = useState<{
    video: VideoArtifact;
    document: DocumentModel;
    notes: ResearchNote[];
    sketches: ResearchSketch[];
    shareExpiresAt?: string;
    shareToken?: string;
    isShareViewer?: boolean;
  } | null>(null);
  const [shareError, setShareError] = useState<string | null>(null);

  const authHeaders = useCallback((): HeadersInit => {
    return authToken ? { Authorization: `Bearer ${authToken}` } : {};
  }, [authToken]);

  const refreshWorkspace = useCallback(async () => {
    setLibraryLoading(true);
    try {
      const [docsRes, langRes, setRes, jobsRes] = await Promise.all([
        fetch('/api/documents', { headers: authHeaders() }),
        fetch('/api/languages'),
        fetch('/api/settings', { headers: authHeaders() }),
        fetch('/api/jobs', { headers: authHeaders() }),
      ]);
      if (docsRes.ok) {
        const d = await docsRes.json();
        setLibraryItems(d.items ?? []);
      }
      if (langRes.ok) {
        const l = await langRes.json();
        setLanguages(l.languages ?? []);
      }
      if (setRes.ok) {
        const s = await setRes.json();
        setSettings(s.settings ?? null);
        setAuditLogs(s.auditLogs ?? []);
      }
      if (jobsRes.ok) {
        const j = await jobsRes.json();
        setJobs(j.jobs ?? []);
      }
    } finally {
      setLibraryLoading(false);
    }
  }, [authHeaders]);

  const openVideoPlayer = useCallback(
    async (videoId: string) => {
      const res = await fetch(`/api/videos/${videoId}`, { headers: authHeaders() });
      if (!res.ok) return;
      const data = await res.json();
      setActivePlayerData({
        video: data.video,
        document: data.document.model,
        notes: data.notes ?? [],
        sketches: data.sketches ?? [],
      });
      setActiveScreen('player');
    },
    [authHeaders]
  );

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const shareToken = params.get('share');
    if (shareToken) {
      fetch(`/api/share/${shareToken}`)
        .then(async (res) => {
          const data = await res.json();
          if (!res.ok) throw new Error(data.error || 'Share link invalid');
          setActivePlayerData({
            video: data.video,
            document: data.document.model,
            notes: data.notes ?? [],
            sketches: data.sketches ?? [],
            shareExpiresAt: data.expiresAt,
            shareToken,
            isShareViewer: true,
          });
          setActiveScreen('player');
        })
        .catch((err) => {
          setShareError(err instanceof Error ? err.message : 'Expired share link');
        });
      return;
    }

    refreshWorkspace().then(() => {
      const reqScreen = params.get('screen') as ActiveScreen | null;
      if (reqScreen && ['library', 'new', 'job', 'settings'].includes(reqScreen)) {
        setActiveScreen(reqScreen);
      }
    });
  }, [refreshWorkspace]);

  async function handleDeleteDocument(documentId: string) {
    const res = await fetch(`/api/documents/${documentId}`, {
      method: 'DELETE',
      headers: authHeaders(),
    });
    if (res.ok) {
      if (activePlayerData?.document.id === documentId) {
        setActivePlayerData(null);
        setActiveScreen('library');
      }
      await refreshWorkspace();
    }
  }

  async function handleRetryStage(jobId: string, stage: JobStageName) {
    const res = await fetch(`/api/jobs/${jobId}/retry`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify({ stage }),
    });
    if (res.ok) {
      await refreshWorkspace();
      setSelectedJobId(jobId);
    }
  }

  async function handleSaveSettings(patch: Partial<WorkspaceSettings>) {
    const res = await fetch('/api/settings', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', ...authHeaders() },
      body: JSON.stringify(patch),
    });
    if (res.ok) {
      const data = await res.json();
      setSettings(data.settings);
      setAuditLogs(data.auditLogs);
    }
  }

  async function handleRunRetentionSweep() {
    const res = await fetch('/api/retention/sweep', {
      method: 'POST',
      headers: authHeaders(),
    });
    const data = await res.json();
    await refreshWorkspace();
    return {
      deletedDocuments: data.deletedDocuments ?? [],
      expiredShareLinks: data.expiredShareLinks ?? 0,
    };
  }

  if (shareError) {
    return (
      <div className="min-h-screen bg-slate-50">
        <TopBar
          activeScreen="library"
          onNavigate={setActiveScreen}
          userEmail={userEmail}
          onOpenAuth={() => setAuthModalOpen(true)}
          isShareViewer
        />
        <main className="mx-auto max-w-xl px-6 py-16 text-center space-y-4">
          <h1 className="font-display text-2xl font-bold text-slate-900">
            Shared Link Unavailable
          </h1>
          <p className="text-sm text-slate-600">{shareError}</p>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 flex flex-col">
      <TopBar
        activeScreen={activeScreen}
        onNavigate={(screen) => {
          setActiveScreen(screen);
        }}
        userEmail={userEmail}
        onOpenAuth={() => setAuthModalOpen(true)}
        isShareViewer={activePlayerData?.isShareViewer}
      />

      {/* Mobile Navigation Strip (<= 15% viewport height) */}
      {!activePlayerData?.isShareViewer && (
        <nav
          aria-label="Mobile navigation"
          className="flex md:hidden border-b border-slate-200 bg-white px-4 py-2 gap-3 overflow-x-auto text-xs font-medium"
        >
          {(
            [
              { id: 'library', label: 'Library' },
              { id: 'new', label: 'New Video' },
              { id: 'job', label: 'Job Progress' },
              { id: 'settings', label: 'Settings' },
            ] as const
          ).map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setActiveScreen(item.id)}
              className={`whitespace-nowrap px-2 py-1 rounded ${
                activeScreen === item.id ? 'bg-blue-50 text-blue-700 font-semibold' : 'text-slate-600'
              }`}
            >
              {item.label}
            </button>
          ))}
        </nav>
      )}

      <div className="flex-1">
        {activeScreen === 'library' && (
          <LibraryScreen
            items={libraryItems}
            loading={libraryLoading}
            languages={languages}
            settings={settings}
            onNewVideo={() => setActiveScreen('new')}
            onJobCreated={async (jobId, videoId) => {
              await refreshWorkspace();
              setSelectedJobId(jobId);
              if (videoId) {
                await openVideoPlayer(videoId);
              } else {
                setActiveScreen('job');
              }
            }}
            onOpenPlayer={openVideoPlayer}
            onInspectJob={(jobId) => {
              setSelectedJobId(jobId);
              setActiveScreen('job');
            }}
            onDeleteDocument={handleDeleteDocument}
          />
        )}

        {activeScreen === 'new' && settings && (
          <NewVideoScreen
            languages={languages}
            settings={settings}
            onJobCreated={async (jobId, videoId) => {
              await refreshWorkspace();
              setSelectedJobId(jobId);
              if (videoId) {
                await openVideoPlayer(videoId);
              } else {
                setActiveScreen('job');
              }
            }}
          />
        )}

        {activeScreen === 'job' && (
          <JobProgressScreen
            jobs={jobs}
            selectedJobId={selectedJobId}
            onSelectJob={setSelectedJobId}
            onRetryStage={handleRetryStage}
            onOpenPlayer={openVideoPlayer}
          />
        )}

        {activeScreen === 'player' && activePlayerData && (
          <PlayerWorkspace
            video={activePlayerData.video}
            document={activePlayerData.document}
            initialNotes={activePlayerData.notes}
            initialSketches={activePlayerData.sketches}
            isShareViewer={activePlayerData.isShareViewer}
            shareExpiresAt={activePlayerData.shareExpiresAt}
            shareToken={activePlayerData.shareToken}
            onAnnotationsChanged={refreshWorkspace}
            onDeleteDocument={handleDeleteDocument}
          />
        )}

        {activeScreen === 'settings' && settings && (
          <SettingsScreen
            settings={settings}
            auditLogs={auditLogs}
            onSaveSettings={handleSaveSettings}
            onRunRetentionSweep={handleRunRetentionSweep}
          />
        )}
      </div>

      <AuthModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        currentEmail={userEmail}
        authMethod={authMethod}
        onAuthenticated={(token, email, _name, method) => {
          setAuthToken(token);
          setUserEmail(email);
          setAuthMethod(method);
        }}
      />
    </div>
  );
}
