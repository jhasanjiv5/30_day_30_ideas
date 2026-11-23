import {
  Download,
  Pause,
  Play,
  Share2,
  SkipBack,
  SkipForward,
  Subtitles,
  Trash2,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import {
  DocumentModel,
  QAResponse,
  ResearchNote,
  ResearchSketch,
  StoryboardScene,
  VideoArtifact,
} from '../types.ts';
import { ApplePreviewReader } from './ApplePreviewReader.tsx';
import { SceneStage } from './SceneStage.tsx';

interface PlayerWorkspaceProps {
  video: VideoArtifact;
  document: DocumentModel;
  initialNotes?: ResearchNote[];
  initialSketches?: ResearchSketch[];
  isShareViewer?: boolean;
  shareExpiresAt?: string;
  shareToken?: string;
  onAnnotationsChanged?: () => void;
  onDeleteDocument?: (documentId: string) => Promise<void>;
}

export function PlayerWorkspace({
  video,
  document,
  initialNotes = [],
  initialSketches = [],
  isShareViewer,
  shareExpiresAt,
  shareToken,
  onAnnotationsChanged,
  onDeleteDocument,
}: PlayerWorkspaceProps) {
  const [workspaceView, setWorkspaceView] = useState<'split' | 'video'>('split');
  const [stageMode, setStageMode] = useState<'interactive' | 'mp4'>('interactive');
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [playbackRate, setPlaybackRate] = useState(1);
  const [showCaptions, setShowCaptions] = useState(true);
  const [rightTab, setRightTab] = useState<'transcript' | 'qa' | 'sources'>('transcript');
  const [selectedCitation, setSelectedCitation] = useState<string | null>(null);

  // Q&A state
  const [questionInput, setQuestionInput] = useState('');
  const [qaLoading, setQaLoading] = useState(false);
  const [qaHistory, setQaHistory] = useState<QAResponse[]>([]);

  // Share link modal state
  const [shareModalOpen, setShareModalOpen] = useState(false);
  const [shareHours, setShareHours] = useState(24);
  const [generatedShareUrl, setGeneratedShareUrl] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const isCaptionsOnly = video.languageCapability === 'captions_only';

  const activeScene: StoryboardScene = useMemo(() => {
    for (let i = video.scenes.length - 1; i >= 0; i -= 1) {
      if (currentTime >= video.scenes[i].startSeconds) {
        return video.scenes[i];
      }
    }
    return video.scenes[0];
  }, [currentTime, video.scenes]);

  const sceneElapsedSeconds = Math.max(0, currentTime - activeScene.startSeconds);

  // Keep <audio> / <video> playbackRate and mute state in sync
  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.playbackRate = playbackRate;
      audioRef.current.muted = isMuted;
    }
    if (videoRef.current) {
      videoRef.current.playbackRate = playbackRate;
      videoRef.current.muted = isMuted;
    }
  }, [playbackRate, isMuted]);

  // Pause audio/video whenever leaving video workspace or switching modes
  useEffect(() => {
    if (workspaceView !== 'video' || stageMode !== 'interactive' || !isPlaying) {
      if (audioRef.current && !audioRef.current.paused) {
        audioRef.current.pause();
      }
    }
    if (workspaceView !== 'video' || stageMode !== 'mp4') {
      if (videoRef.current && !videoRef.current.paused) {
        videoRef.current.pause();
      }
    }
  }, [workspaceView, stageMode, isPlaying]);

  // Interactive Stage timer (synced to narration audio clock when playing)
  useEffect(() => {
    if (!isPlaying || stageMode !== 'interactive' || workspaceView !== 'video') return;
    const interval = setInterval(() => {
      const audioEl = audioRef.current;
      if (
        audioEl &&
        !audioEl.paused &&
        !audioEl.ended &&
        Number.isFinite(audioEl.duration) &&
        audioEl.duration > 0
      ) {
        const audioPos = audioEl.currentTime;
        if (audioPos >= video.durationSeconds) {
          audioEl.pause();
          setIsPlaying(false);
          setCurrentTime(video.durationSeconds);
        } else {
          setCurrentTime(audioPos);
        }
        return;
      }

      setCurrentTime((prev) => {
        const next = prev + 0.25 * playbackRate;
        if (next >= video.durationSeconds) {
          setIsPlaying(false);
          return video.durationSeconds;
        }
        return next;
      });
    }, 250);
    return () => clearInterval(interval);
  }, [isPlaying, stageMode, workspaceView, playbackRate, video.durationSeconds]);

  function seekTo(seconds: number) {
    const clamped = Math.max(0, Math.min(video.durationSeconds, seconds));
    setCurrentTime(clamped);
    if (stageMode === 'mp4' && videoRef.current) {
      videoRef.current.currentTime = clamped;
    }
    if (audioRef.current) {
      audioRef.current.currentTime = clamped;
    }
  }

  function togglePlay() {
    if (stageMode === 'mp4' && videoRef.current) {
      if (videoRef.current.paused) {
        videoRef.current.playbackRate = playbackRate;
        videoRef.current.muted = isMuted;
        videoRef.current.play().catch(() => {});
        setIsPlaying(true);
      } else {
        videoRef.current.pause();
        setIsPlaying(false);
      }
      return;
    }

    const nextPlaying = !isPlaying;
    const targetTime = currentTime >= video.durationSeconds ? 0 : currentTime;
    if (currentTime >= video.durationSeconds) {
      setCurrentTime(0);
    }

    if (audioRef.current) {
      if (nextPlaying && !isCaptionsOnly) {
        if (Math.abs(audioRef.current.currentTime - targetTime) > 0.35 || currentTime >= video.durationSeconds) {
          audioRef.current.currentTime = targetTime;
        }
        audioRef.current.playbackRate = playbackRate;
        audioRef.current.muted = isMuted;
        audioRef.current.play().catch(() => {});
      } else {
        audioRef.current.pause();
      }
    }

    setIsPlaying(nextPlaying);
  }

  function resolveCitationInfo(key: string) {
    const p = document.paragraphs.find((item) => item.citationKey === key);
    if (p) return { title: `${p.sectionTitle} · Page ${p.page}`, excerpt: p.text, kind: 'Document Span' };
    const t = document.tables.find((item) => item.citationKey === key);
    if (t) return { title: `${t.label} · Page ${t.page}`, excerpt: t.caption, kind: 'Parsed Table' };
    const f = document.figures.find((item) => item.citationKey === key);
    if (f) return { title: `${f.label} · Page ${f.page}`, excerpt: f.caption, kind: 'Paper Figure' };
    const e = document.equations.find((item) => item.citationKey === key);
    if (e) return { title: `${e.label} · Page ${e.page}`, excerpt: e.description, kind: 'Equation' };
    const ext = video.clarifications.find((c) => c.url === key);
    if (ext) {
      return {
        title: `${ext.title} (Tier ${ext.tier} · ${ext.providerName})`,
        excerpt: ext.quote,
        kind: ext.viewLabel || (ext.confidenceLabel === 'lower confidence' ? 'Lower confidence' : 'External Source'),
        url: ext.url,
      };
    }
    return { title: key, excerpt: 'Verified source reference.', kind: 'Citation' };
  }

  async function askQuestion(qText?: string) {
    const q = (qText ?? questionInput).trim();
    if (!q) return;
    setQaLoading(true);
    if (!qText) setQuestionInput('');
    try {
      const res = await fetch(`/api/videos/${video.id}/qa`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: q }),
      });
      const data = (await res.json()) as QAResponse;
      setQaHistory((prev) => [data, ...prev]);
    } finally {
      setQaLoading(false);
    }
  }

  async function handleCreateShareLink() {
    const res = await fetch(`/api/videos/${video.id}/share`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ expiresInHours: shareHours }),
    });
    const data = await res.json();
    if (res.ok && data.shareLink) {
      setGeneratedShareUrl(`${window.location.origin}/?share=${data.shareLink.token}`);
    }
  }

  function formatTime(sec: number): string {
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${String(s).padStart(2, '0')}`;
  }

  const isRtl = video.languageDir === 'rtl';
  const shareQuery = shareToken ? `&share=${encodeURIComponent(shareToken)}` : '';
  const suggestedQuestions = useMemo(() => {
    if (document.id === 'doc_monsoon_2025') {
      return [
        'What is MonsoonFormer 5-day RMSE compared to Full-Attention?',
        'What is the limitation beyond day 7 and what does Rao et al. say?',
        'What was the GDP growth rate of Brazil in 1994?',
      ];
    }
    const firstSec = document.sections[0]?.title ?? 'Introduction';
    return [
      `What are the main findings in ${firstSec}?`,
      document.tables[0]
        ? `What values are reported in ${document.tables[0].label}?`
        : `What limitations or challenges are noted in ${document.title}?`,
      'What was the GDP growth rate of Brazil in 1994?',
    ];
  }, [document]);

  return (
    <div className="mx-auto max-w-7xl px-6 py-6 space-y-6">
      {video.audioUrl && (
        <audio
          ref={audioRef}
          src={video.audioUrl}
          preload="auto"
          muted={isMuted}
          onEnded={() => {
            setIsPlaying(false);
            setCurrentTime(video.durationSeconds);
          }}
        />
      )}
      {/* Document Header */}
      <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4 border-b border-slate-200 pb-5">
        <div className="space-y-1.5 max-w-3xl">
          <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500">
            <span>{document.venue}</span>
            <span aria-hidden="true">·</span>
            <span>Depth: {video.depth}</span>
            <span aria-hidden="true">·</span>
            <span>Language: {video.language.toUpperCase()}</span>
            <span aria-hidden="true">·</span>
            <span>Voice: {video.ttsVoice}</span>
            {shareExpiresAt && (
              <>
                <span aria-hidden="true">·</span>
                <span className="font-medium text-amber-700">
                  Viewer link expires {new Date(shareExpiresAt).toLocaleString()}
                </span>
              </>
            )}
          </div>
          <h1 className="font-display text-2xl font-bold tracking-tight text-slate-900">
            {document.title}
          </h1>
        </div>

        <div className="flex flex-wrap items-center gap-2 shrink-0">
          <div className="flex items-center rounded-lg bg-slate-100 p-1">
            <button
              type="button"
              onClick={() => setWorkspaceView('split')}
              className={`rounded-md px-3 py-1.5 text-xs font-medium transition-colors whitespace-nowrap ${
                workspaceView === 'split'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Document & Artifacts
            </button>
            <button
              type="button"
              onClick={() => setWorkspaceView('video')}
              className={`rounded-md px-3 py-1.5 text-xs font-medium transition-colors whitespace-nowrap ${
                workspaceView === 'video'
                  ? 'bg-white text-slate-900 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Video Podcast
            </button>
          </div>

          {workspaceView === 'video' && (
            <div className="flex items-center rounded-lg bg-slate-100 p-1">
              <button
                type="button"
                onClick={() => {
                  setStageMode('interactive');
                  setIsPlaying(false);
                }}
                className={`rounded-md px-3 py-1.5 text-xs font-medium transition-colors whitespace-nowrap ${
                  stageMode === 'interactive'
                    ? 'bg-white text-slate-900 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Interactive Stage
              </button>
              <button
                type="button"
                onClick={() => {
                  setStageMode('mp4');
                  setIsPlaying(false);
                }}
                className={`rounded-md px-3 py-1.5 text-xs font-medium transition-colors whitespace-nowrap ${
                  stageMode === 'mp4'
                    ? 'bg-white text-slate-900 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                MP4 Video Stream
              </button>
            </div>
          )}

          <a
            href={video.mp4Url}
            download={`drishya-${video.id}.mp4`}
            className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50 whitespace-nowrap"
          >
            <Download className="h-3.5 w-3.5" />
            MP4
          </a>

          <button
            type="button"
            onClick={() => {
              setGeneratedShareUrl(null);
              setShareModalOpen(true);
            }}
            className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50 whitespace-nowrap"
          >
            <Share2 className="h-3.5 w-3.5" />
            {isShareViewer ? 'Export Research' : 'Share & Export'}
          </button>

          {!isShareViewer && onDeleteDocument && (
            <button
              type="button"
              disabled={deleting}
              onClick={async () => {
                setDeleting(true);
                await onDeleteDocument(document.id);
                setDeleting(false);
              }}
              className="inline-flex items-center gap-1.5 rounded-lg border border-red-200 bg-white px-3 py-2 text-xs font-medium text-red-700 hover:bg-red-50 whitespace-nowrap disabled:opacity-50"
            >
              <Trash2 className="h-3.5 w-3.5" />
              {deleting ? 'Deleting...' : 'Delete Now'}
            </button>
          )}
        </div>
      </div>

      {workspaceView === 'split' ? (
        <ApplePreviewReader
          document={document}
          video={video}
          initialNotes={initialNotes}
          initialSketches={initialSketches}
          isShareViewer={isShareViewer}
          onAnnotationsUpdated={onAnnotationsChanged}
          onJumpToVideoScene={(seconds) => {
            const clamped = Math.max(0, Math.min(video.durationSeconds, seconds));
            setWorkspaceView('video');
            setStageMode('interactive');
            setCurrentTime(clamped);
            setIsPlaying(true);
            if (audioRef.current && !isCaptionsOnly) {
              audioRef.current.currentTime = clamped;
              audioRef.current.playbackRate = playbackRate;
              audioRef.current.muted = isMuted;
              audioRef.current.play().catch(() => {});
            }
          }}
        />
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Zone: Stage + Transport + Chapters */}
        <div className="lg:col-span-7 xl:col-span-8 space-y-4">
          <SceneStage
            video={video}
            document={document}
            activeScene={activeScene}
            sceneElapsedSeconds={sceneElapsedSeconds}
            showCaptions={showCaptions}
            stageMode={stageMode}
            videoRef={videoRef}
            onVideoTimeUpdate={(sec) => setCurrentTime(sec)}
            onVideoEnded={() => setIsPlaying(false)}
          />

          {/* Player Controls & Chapter Scrubber */}
          <div className="rounded-xl border border-slate-200 bg-white p-4 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  aria-label="Previous chapter"
                  onClick={() => {
                    const prevIdx = Math.max(0, activeScene.order - 2);
                    seekTo(video.scenes[prevIdx].startSeconds);
                  }}
                  className="rounded-lg border border-slate-200 p-2 text-slate-700 hover:bg-slate-50"
                >
                  <SkipBack className="h-4 w-4" />
                </button>
                <button
                  type="button"
                  onClick={togglePlay}
                  className="inline-flex items-center gap-2 rounded-lg bg-blue-700 px-4 py-2 text-xs font-semibold text-white hover:bg-blue-800"
                >
                  {isPlaying ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                  {isPlaying ? 'Pause' : 'Play'}
                </button>
                <button
                  type="button"
                  aria-label="Next chapter"
                  onClick={() => {
                    const nextIdx = Math.min(video.scenes.length - 1, activeScene.order);
                    seekTo(video.scenes[nextIdx].startSeconds);
                  }}
                  className="rounded-lg border border-slate-200 p-2 text-slate-700 hover:bg-slate-50"
                >
                  <SkipForward className="h-4 w-4" />
                </button>
                <span className="ml-2 font-mono text-xs tabular-nums text-slate-600">
                  {formatTime(currentTime)} / {formatTime(video.durationSeconds)}
                </span>
              </div>

              <div className="flex items-center gap-2">
                {isCaptionsOnly ? (
                  <span
                    title="Voice TTS is disabled for this language; captions only"
                    className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs font-medium text-slate-500"
                  >
                    <VolumeX className="h-3.5 w-3.5" />
                    Captions Only
                  </span>
                ) : (
                  <button
                    type="button"
                    aria-label={isMuted ? 'Unmute narration audio' : 'Mute narration audio'}
                    onClick={() => setIsMuted((m) => !m)}
                    className={`inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium ${
                      !isMuted
                        ? 'border-blue-200 bg-blue-50 text-blue-800'
                        : 'border-slate-200 bg-white text-slate-600'
                    }`}
                  >
                    {isMuted ? (
                      <VolumeX className="h-3.5 w-3.5" />
                    ) : (
                      <Volume2 className="h-3.5 w-3.5" />
                    )}
                    {isMuted ? 'Muted' : 'Audio On'}
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setShowCaptions((c) => !c)}
                  className={`inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium ${
                    showCaptions
                      ? 'border-blue-200 bg-blue-50 text-blue-800'
                      : 'border-slate-200 bg-white text-slate-600'
                  }`}
                >
                  <Subtitles className="h-3.5 w-3.5" />
                  Captions {showCaptions ? 'On' : 'Off'}
                </button>
                <select
                  aria-label="Playback speed"
                  value={playbackRate}
                  onChange={(e) => setPlaybackRate(Number(e.target.value))}
                  className="rounded-lg border border-slate-200 bg-white px-2.5 py-1.5 font-mono text-xs text-slate-700"
                >
                  <option value={1}>1.0x</option>
                  <option value={1.25}>1.25x</option>
                  <option value={1.5}>1.5x</option>
                </select>
              </div>
            </div>

            {/* Scrubber */}
            <input
              type="range"
              aria-label="Video timeline scrubber"
              min={0}
              max={video.durationSeconds}
              step={0.5}
              value={currentTime}
              onChange={(e) => seekTo(Number(e.target.value))}
              className="w-full accent-blue-700 cursor-pointer"
            />

            {/* Chapter Markers */}
            <div>
              <div className="mb-2 text-xs font-semibold text-slate-600">
                Chapters ({video.chapters.length})
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
                {video.chapters.map((ch, idx) => {
                  const active = ch.sceneId === activeScene.id;
                  return (
                    <button
                      key={ch.sceneId}
                      type="button"
                      onClick={() => seekTo(ch.startSeconds)}
                      className={`text-left rounded-lg border px-3 py-2 transition-colors ${
                        active
                          ? 'border-blue-700 bg-blue-50 text-slate-900'
                          : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2 text-[11px] font-mono tabular-nums text-slate-500">
                        <span>Ch. {idx + 1}</span>
                        <span>{formatTime(ch.startSeconds)}</span>
                      </div>
                      <div className="mt-0.5 truncate text-xs font-medium">{ch.title}</div>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Inline Citation Inspector when a citation is clicked */}
          {selectedCitation && (
            <div className="rounded-xl border border-blue-200 bg-blue-50/50 p-4 space-y-2">
              {(() => {
                const info = resolveCitationInfo(selectedCitation);
                return (
                  <>
                    <div className="flex items-center justify-between gap-4">
                      <div className="text-xs font-semibold text-blue-900">
                        Citation Inspector · {info.kind} · {info.title}
                      </div>
                      <button
                        type="button"
                        onClick={() => setSelectedCitation(null)}
                        className="text-xs font-medium text-blue-700 hover:underline"
                      >
                        Close
                      </button>
                    </div>
                    <p className="text-sm text-slate-800 leading-relaxed">{info.excerpt}</p>
                    <div className="font-mono text-xs text-slate-500">{selectedCitation}</div>
                  </>
                );
              })()}
            </div>
          )}
        </div>

        {/* Right Zone: Transcript, Q&A Side Panel, Sources */}
        <div className="lg:col-span-5 xl:col-span-4 rounded-xl border border-slate-200 bg-white overflow-hidden">
          <div className="flex border-b border-slate-200 bg-slate-50 p-1 gap-1" role="tablist">
            {(
              [
                { id: 'transcript', label: 'Transcript' },
                { id: 'qa', label: 'Grounded Q&A' },
                { id: 'sources', label: 'Sources & Audit' },
              ] as const
            ).map((tab) => (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={rightTab === tab.id}
                onClick={() => setRightTab(tab.id)}
                className={`flex-1 rounded-lg px-3 py-2 text-xs font-semibold transition-colors whitespace-nowrap ${
                  rightTab === tab.id
                    ? 'bg-white text-slate-900 shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className="max-h-[680px] overflow-y-auto p-4">
            {rightTab === 'transcript' && (
              <div className="space-y-4" dir={isRtl ? 'rtl' : 'ltr'}>
                <div className="text-xs text-slate-500">
                  Every narrated sentence is verified against a document span or external source. Click any citation to inspect its exact source excerpt.
                </div>
                {video.scenes.map((scene) => {
                  const isCurrent = scene.id === activeScene.id;
                  return (
                    <div
                      key={scene.id}
                      className={`rounded-lg border p-3.5 space-y-2 transition-colors ${
                        isCurrent ? 'border-blue-300 bg-blue-50/40' : 'border-slate-200 bg-white'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <button
                          type="button"
                          onClick={() => seekTo(scene.startSeconds)}
                          className="text-xs font-semibold text-blue-700 hover:underline text-left"
                        >
                          {scene.order}. {scene.translatedChapterTitle || scene.chapterTitle}
                        </button>
                        <span className="font-mono text-[11px] tabular-nums text-slate-500">
                          {formatTime(scene.startSeconds)}
                        </span>
                      </div>

                      <div className="space-y-2">
                        {scene.sentences.map((sent) => (
                          <div key={sent.id} className="text-sm text-slate-800 leading-relaxed">
                            <span>{sent.translatedText || sent.text} </span>
                            <span className="inline-flex flex-wrap gap-1.5 align-baseline">
                              {sent.citations.map((cit) => (
                                <button
                                  key={cit}
                                  type="button"
                                  onClick={() => setSelectedCitation(cit)}
                                  className="font-mono text-[11px] font-medium text-blue-700 underline decoration-blue-300 hover:text-blue-900"
                                >
                                  [{cit}]
                                </button>
                              ))}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {rightTab === 'qa' && (
              <div className="space-y-4">
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    askQuestion();
                  }}
                  className="space-y-2"
                >
                  <label htmlFor="qa-input" className="block text-xs font-semibold text-slate-700">
                    Ask a question (document-first hybrid BM25 + RRF retrieval)
                  </label>
                  <div className="flex gap-2">
                    <input
                      id="qa-input"
                      type="text"
                      value={questionInput}
                      onChange={(e) => setQuestionInput(e.target.value)}
                      placeholder="e.g., What is MonsoonFormer 5-day RMSE?"
                      className="flex-1 rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-blue-700 focus:outline-none"
                    />
                    <button
                      type="submit"
                      disabled={qaLoading}
                      className="rounded-lg bg-blue-700 px-4 py-2 text-xs font-semibold text-white hover:bg-blue-800 disabled:opacity-50 whitespace-nowrap"
                    >
                      {qaLoading ? 'Searching...' : 'Ask'}
                    </button>
                  </div>
                </form>

                {/* Quick suggested questions */}
                <div className="space-y-1.5">
                  <div className="text-xs font-medium text-slate-500">Suggested checks:</div>
                  <div className="flex flex-col gap-1.5">
                    {suggestedQuestions.map((sample) => (
                      <button
                        key={sample}
                        type="button"
                        onClick={() => askQuestion(sample)}
                        className="text-left rounded-lg border border-slate-200 px-3 py-1.5 text-xs text-slate-700 hover:bg-slate-50"
                      >
                        {sample}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Q&A Answers */}
                <div className="space-y-4 pt-2">
                  {qaHistory.map((item, idx) => (
                    <div
                      key={`${item.question}-${idx}`}
                      className="rounded-lg border border-slate-200 bg-slate-50/70 p-3.5 space-y-3"
                    >
                      <div className="text-xs font-semibold text-slate-900">
                        Q: {item.question}
                      </div>

                      {!item.answered ? (
                        <p className="text-sm font-medium text-slate-700">
                          {item.refusalText}
                        </p>
                      ) : (
                        <div className="space-y-2.5">
                          {item.sentences.map((s, sIdx) => (
                            <div key={sIdx} className="text-sm text-slate-800 leading-relaxed space-y-1">
                              <p>{s.text}</p>
                              <div className="flex flex-wrap items-center gap-3 text-xs">
                                {s.citations.map((cit) => (
                                  <button
                                    key={cit}
                                    type="button"
                                    onClick={() => setSelectedCitation(cit)}
                                    className="font-mono text-[11px] font-medium text-blue-700 underline"
                                  >
                                    {cit}
                                  </button>
                                ))}
                                {s.jumpToSeconds !== undefined && (
                                  <button
                                    type="button"
                                    onClick={() => seekTo(s.jumpToSeconds!)}
                                    className="font-semibold text-emerald-700 hover:underline"
                                  >
                                    Show me ({formatTime(s.jumpToSeconds)})
                                  </button>
                                )}
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {rightTab === 'sources' && (
              <div className="space-y-5">
                {/* Grounding & Chart Accuracy Audit */}
                <div className="space-y-2">
                  <h3 className="text-xs font-semibold text-slate-900">
                    Grounding & Chart Accuracy Report
                  </h3>
                  <div className="rounded-lg border border-slate-200 p-3 text-xs text-slate-700 space-y-1.5 tabular-nums">
                    <div>
                      Uncited sentences stripped: <strong>{video.droppedUncitedSentences}</strong>
                    </div>
                    <div>
                      Number guard violations blocked: <strong>{video.numberGuardViolations}</strong>
                    </div>
                    <div>
                      Translation placeholder guard:{' '}
                      <strong>{video.translationGuardVerified ? 'Verified' : 'Check required'}</strong>
                    </div>
                    {video.chartAccuracyReport.map((rep) => (
                      <div key={rep.sceneId} className="pt-1 border-t border-slate-100">
                        {rep.tableLabel}: <strong>{rep.verified ? '100% Exact Match' : 'Mismatch'}</strong>{' '}
                        ({rep.checkedCells} table cells verified)
                      </div>
                    ))}
                  </div>
                </div>

                {/* Clarification Sources Ranked by Tier */}
                <div className="space-y-2.5">
                  <h3 className="text-xs font-semibold text-slate-900">
                    Clarification Sources (Ranked by Tier)
                  </h3>
                  {video.clarifications.map((src) => (
                    <div
                      key={src.id}
                      className="rounded-lg border border-slate-200 p-3 space-y-1.5"
                    >
                      <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-500">
                        <span className="font-semibold text-slate-800">Tier {src.tier}</span>
                        <span aria-hidden="true">·</span>
                        <span>{src.providerName}</span>
                        <span aria-hidden="true">·</span>
                        <span className="tabular-nums">{src.year}</span>
                        {src.confidenceLabel === 'lower confidence' && (
                          <>
                            <span aria-hidden="true">·</span>
                            <span className="font-semibold text-amber-700">Lower confidence</span>
                          </>
                        )}
                        {src.viewLabel === 'Differing view' && (
                          <>
                            <span aria-hidden="true">·</span>
                            <span className="font-semibold text-red-700">Differing view</span>
                          </>
                        )}
                      </div>
                      <div className="text-xs font-semibold text-slate-900">{src.title}</div>
                      <p className="text-xs text-slate-700 leading-relaxed">“{src.quote}”</p>
                      <div className="font-mono text-[11px] text-blue-700 truncate">{src.url}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
        </div>
      )}

      {/* Share & Platform-Independent Export Modal */}
      {shareModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="share-dialog-title"
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4"
        >
          <div className="w-full max-w-lg rounded-xl border border-slate-200 bg-white p-6 space-y-5">
            <div className="space-y-1">
              <h2 id="share-dialog-title" className="text-lg font-semibold text-slate-900">
                Share &amp; Export Annotated Research
              </h2>
              <p className="text-xs text-slate-600">
                Download your complete research workspace—paper spans, tables, equations, anchored notes, vector SVG sketches, video transcript, and clarifications—in an open, platform-independent format.
              </p>
            </div>

            <div className="space-y-2">
              <div className="text-xs font-semibold text-slate-800">
                Platform-Independent Complete Exports
              </div>
              <div className="grid grid-cols-1 gap-2">
                <a
                  href={`/api/documents/${document.id}/export?format=html${shareQuery}`}
                  download
                  className="flex items-center justify-between rounded-lg border border-blue-200 bg-blue-50/50 px-3.5 py-2.5 text-xs hover:bg-blue-50 transition-colors"
                >
                  <div>
                    <div className="font-semibold text-blue-900">
                      Portable HTML Notebook (.html) · Recommended
                    </div>
                    <div className="text-[11px] text-slate-600">
                      Opens offline in any browser (macOS, Windows, Linux, mobile) &amp; prints cleanly to PDF with inline SVG sketches.
                    </div>
                  </div>
                  <Download className="h-4 w-4 text-blue-700 shrink-0 ml-3" />
                </a>

                <a
                  href={`/api/documents/${document.id}/export?format=md${shareQuery}`}
                  download
                  className="flex items-center justify-between rounded-lg border border-slate-200 bg-white px-3.5 py-2.5 text-xs hover:bg-slate-50 transition-colors"
                >
                  <div>
                    <div className="font-semibold text-slate-900">
                      Markdown + Vector SVG (.md)
                    </div>
                    <div className="text-[11px] text-slate-600">
                      Plain-text CommonMark for Obsidian, Notion, Logseq, or Git repositories.
                    </div>
                  </div>
                  <Download className="h-4 w-4 text-slate-600 shrink-0 ml-3" />
                </a>

                <a
                  href={`/api/documents/${document.id}/export?format=json${shareQuery}`}
                  download
                  className="flex items-center justify-between rounded-lg border border-slate-200 bg-white px-3.5 py-2.5 text-xs hover:bg-slate-50 transition-colors"
                >
                  <div>
                    <div className="font-semibold text-slate-900">
                      Structured Research Bundle (.json)
                    </div>
                    <div className="text-[11px] text-slate-600">
                      Machine-readable archive (`drishya-research-bundle/v1`) for scripts and archival storage.
                    </div>
                  </div>
                  <Download className="h-4 w-4 text-slate-600 shrink-0 ml-3" />
                </a>
              </div>
            </div>

            {!isShareViewer && (
              <div className="border-t border-slate-200 pt-4 space-y-3">
                <div className="text-xs font-semibold text-slate-800">
                  Expiring Read-Only Viewer Link
                </div>
                <p className="text-[11px] text-slate-600">
                  Grants collaborators live browser access to the paper, your notes &amp; sketches, video podcast, and exports.
                </p>
                <div className="flex items-center gap-2">
                  <select
                    aria-label="Link expiry"
                    value={shareHours}
                    onChange={(e) => setShareHours(Number(e.target.value))}
                    className="flex-1 rounded-lg border border-slate-300 px-3 py-2 text-xs text-slate-900"
                  >
                    <option value={1}>Expires in 1 hour</option>
                    <option value={24}>Expires in 24 hours</option>
                    <option value={168}>Expires in 7 days</option>
                  </select>
                  <button
                    type="button"
                    onClick={handleCreateShareLink}
                    className="rounded-lg bg-blue-700 px-4 py-2 text-xs font-semibold text-white hover:bg-blue-800 whitespace-nowrap"
                  >
                    Generate Link
                  </button>
                </div>
                {generatedShareUrl && (
                  <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-3 space-y-1">
                    <div className="text-xs font-semibold text-emerald-900">Expiring link created:</div>
                    <input
                      readOnly
                      value={generatedShareUrl}
                      className="w-full rounded border border-emerald-300 bg-white px-2 py-1 font-mono text-xs text-slate-800"
                    />
                  </div>
                )}
              </div>
            )}

            <div className="flex justify-end">
              <button
                type="button"
                onClick={() => setShareModalOpen(false)}
                className="rounded-lg border border-slate-300 px-4 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
