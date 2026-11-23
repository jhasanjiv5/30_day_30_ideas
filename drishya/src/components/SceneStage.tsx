import katex from 'katex';
import { useMemo, useState } from 'react';
import { DocumentModel, StoryboardScene, VideoArtifact } from '../types.ts';

interface SceneStageProps {
  video: VideoArtifact;
  document: DocumentModel;
  activeScene: StoryboardScene;
  sceneElapsedSeconds: number;
  showCaptions: boolean;
  stageMode: 'interactive' | 'mp4';
  videoRef: React.RefObject<HTMLVideoElement | null>;
  onVideoTimeUpdate: (seconds: number) => void;
  onVideoEnded: () => void;
}

export function SceneStage({
  video,
  document,
  activeScene,
  sceneElapsedSeconds,
  showCaptions,
  stageMode,
  videoRef,
  onVideoTimeUpdate,
  onVideoEnded,
}: SceneStageProps) {
  const [imgFailed, setImgFailed] = useState<Record<string, boolean>>({});
  const progress = Math.min(
    1,
    Math.max(0.05, sceneElapsedSeconds / Math.max(1, activeScene.durationSeconds))
  );
  const currentStep = Math.min(4, Math.max(1, Math.ceil(progress * 4)));
  const isRtl = video.languageDir === 'rtl';

  const renderedLatexHtml = useMemo(() => {
    if (activeScene.visualSpec.kind !== 'equation') return '';
    try {
      return katex.renderToString(activeScene.visualSpec.latex, {
        throwOnError: false,
        displayMode: true,
      });
    } catch {
      return activeScene.visualSpec.latex;
    }
  }, [activeScene]);

  if (stageMode === 'mp4') {
    return (
      <div className="relative aspect-video w-full overflow-hidden rounded-xl border border-slate-800 bg-slate-950">
        <video
          ref={videoRef}
          controls
          playsInline
          className="h-full w-full object-contain"
          src={video.mp4Url}
          onTimeUpdate={(e) => onVideoTimeUpdate(e.currentTarget.currentTime)}
          onEnded={onVideoEnded}
        >
          <track
            kind="captions"
            src={video.vttUrl}
            srcLang={video.language}
            label={video.language.toUpperCase()}
            default
          />
        </video>
      </div>
    );
  }

  const spec = activeScene.visualSpec;
  const chapterHeading = activeScene.translatedChapterTitle || activeScene.chapterTitle;
  const captionText = activeScene.translatedNarration || activeScene.narration;

  return (
    <div
      dir={isRtl ? 'rtl' : 'ltr'}
      className={`relative aspect-video w-full overflow-hidden rounded-xl border border-slate-800 bg-slate-950 text-slate-50 flex flex-col justify-between ${
        isRtl ? 'urdu-rtl' : ''
      }`}
    >
      {/* Top Scene Header */}
      <div className="flex items-center justify-between gap-4 border-b border-slate-800/80 bg-slate-900/70 px-6 py-3">
        <div className="flex items-center gap-3 min-w-0">
          <span className="font-mono text-xs font-medium text-blue-400 whitespace-nowrap shrink-0">
            Scene {activeScene.order}/{video.scenes.length}
          </span>
          <span className="text-slate-600" aria-hidden="true">
            ·
          </span>
          <h3 className="truncate text-sm font-semibold text-slate-100">
            {chapterHeading}
          </h3>
        </div>
        <div className="font-mono text-xs text-slate-400 whitespace-nowrap shrink-0">
          {activeScene.citations.slice(0, 2).join(' · ')}
        </div>
      </div>

      {/* Main Animated 2D Visual Canvas */}
      <div className="relative flex-1 overflow-hidden p-6 flex items-center justify-center">
        {spec.kind === 'title' || spec.kind === 'takeaway' ? (
          <div className="w-full max-w-3xl space-y-5">
            <div className="space-y-2">
              {spec.isAnalogy && (
                <div className="text-xs font-semibold tracking-wide text-amber-300">
                  Beginner Analogy (Marked for Clarity)
                </div>
              )}
              <h4 className="font-display text-2xl sm:text-3xl font-bold tracking-tight text-white">
                {spec.title}
              </h4>
              <p className="text-sm sm:text-base text-slate-300">{spec.subtitle}</p>
            </div>
            <ul className="space-y-2.5 pt-2">
              {spec.bullets.map((bullet, idx) => {
                const visible = idx < Math.max(1, Math.ceil(progress * spec.bullets.length));
                return (
                  <li
                    key={bullet}
                    className={`flex items-start gap-3 rounded-lg border border-slate-800 bg-slate-900/70 px-4 py-2.5 text-sm text-slate-100 transition-opacity duration-300 ${
                      visible ? 'opacity-100' : 'opacity-30'
                    }`}
                  >
                    <span className="font-mono text-xs font-semibold text-blue-400 tabular-nums mt-0.5">
                      0{idx + 1}
                    </span>
                    <span>{bullet}</span>
                  </li>
                );
              })}
            </ul>
          </div>
        ) : null}

        {spec.kind === 'diagram' ? (
          <div className="w-full max-w-4xl space-y-4">
            <div className="flex items-center justify-between text-xs text-slate-400">
              <span className="font-semibold text-slate-200">{spec.title}</span>
              <span className="font-mono tabular-nums">
                Step {Math.min(currentStep, spec.nodes.length)} of {spec.nodes.length}
              </span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-3 items-stretch">
              {spec.nodes.map((node, idx) => {
                const active = node.step <= currentStep;
                const edge = spec.edges.find((e) => e.from === node.id);
                return (
                  <div key={node.id} className="flex flex-col justify-between gap-2">
                    <div
                      className={`flex-1 rounded-lg border p-3.5 transition-all duration-300 ${
                        active
                          ? 'border-blue-500 bg-blue-950/50 text-white'
                          : 'border-slate-800 bg-slate-900/50 text-slate-500'
                      }`}
                    >
                      <div className="font-mono text-[11px] text-blue-300">
                        {node.group} · Step {node.step}
                      </div>
                      <div className="mt-1.5 text-sm font-semibold leading-snug">
                        {node.label}
                      </div>
                    </div>
                    {edge && idx < spec.nodes.length - 1 && (
                      <div className="font-mono text-[11px] text-center text-slate-400">
                        {isRtl ? '←' : '→'} {edge.label || 'flows to'}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        ) : null}

        {spec.kind === 'chart' ? (
          <div className="w-full max-w-3xl space-y-3" dir="ltr">
            <div className="flex items-center justify-between gap-4">
              <div>
                <h4 className="text-base font-semibold text-white">{spec.title}</h4>
                <p className="text-xs text-slate-400">
                  Values loaded verbatim from {spec.tableId} · 100% table-verified
                </p>
              </div>
              <div className="flex items-center gap-4 text-xs">
                <span className="flex items-center gap-1.5 text-blue-300">
                  <span className="inline-block h-2.5 w-2.5 rounded-sm bg-blue-500" />
                  {spec.yColumns[0]}
                </span>
                {spec.yColumns[1] && (
                  <span className="flex items-center gap-1.5 text-emerald-300">
                    <span className="inline-block h-2.5 w-2.5 rounded-sm bg-emerald-500" />
                    {spec.yColumns[1]}
                  </span>
                )}
              </div>
            </div>

            <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
              {(() => {
                const series = spec.resolvedSeries ?? [];
                const maxVal = Math.max(
                  1,
                  ...series.flatMap((row) =>
                    spec.yColumns.map((col) => Number(row.values[col] ?? 0))
                  )
                );
                return (
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 items-end h-44 pt-4">
                    {series.map((row) => {
                      const isHighlight = row.label === spec.highlightRow;
                      return (
                        <div
                          key={row.label}
                          className={`flex flex-col items-center justify-end h-full rounded-md p-2 ${
                            isHighlight ? 'bg-blue-950/40 ring-1 ring-blue-500/60' : ''
                          }`}
                        >
                          <div className="flex items-end gap-2 h-28 w-full justify-center">
                            {spec.yColumns.map((col, cIdx) => {
                              const val = Number(row.values[col] ?? 0);
                              const pct = Math.max(10, Math.round((val / maxVal) * 100));
                              return (
                                <div key={col} className="flex flex-col items-center gap-1 h-full justify-end">
                                  <span className="font-mono text-[11px] tabular-nums text-slate-200">
                                    {val}
                                  </span>
                                  <div
                                    style={{ height: `${pct}%` }}
                                    className={`w-6 rounded-t transition-all duration-500 ${
                                      cIdx === 0 ? 'bg-blue-500' : 'bg-emerald-500'
                                    }`}
                                  />
                                </div>
                              );
                            })}
                          </div>
                          <div className="mt-2 text-xs font-medium text-slate-200 text-center truncate w-full">
                            {row.label}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                );
              })()}
            </div>
          </div>
        ) : null}

        {spec.kind === 'figure' ? (
          <div className="w-full h-full flex flex-col items-center justify-center gap-2" dir="ltr">
            {(() => {
              const fig = document.figures.find((f) => f.id === spec.figureId) ?? document.figures[0];
              const failed = !fig || imgFailed[fig.id];
              return (
                <>
                  <div className="relative max-h-[250px] w-full max-w-2xl overflow-hidden rounded-lg border border-slate-700 bg-white">
                    {!failed ? (
                      <img
                        src={fig.imageUrl}
                        alt={fig.caption}
                        referrerPolicy="no-referrer"
                        onError={() => setImgFailed((prev) => ({ ...prev, [fig.id]: true }))}
                        className="h-full max-h-[250px] w-full object-contain"
                      />
                    ) : (
                      <div className="flex h-48 w-full flex-col items-center justify-center bg-slate-900 p-4 text-center text-slate-300">
                        <span className="font-mono text-xs text-blue-400">{fig?.label ?? 'Paper Figure'}</span>
                        <span className="mt-1 text-sm">{spec.title}</span>
                      </div>
                    )}
                    {spec.highlightBoxes.map((box) => {
                      const active = box.step <= currentStep;
                      return (
                        <div
                          key={box.label}
                          style={{
                            left: `${box.xPct}%`,
                            top: `${box.yPct}%`,
                            width: `${box.wPct}%`,
                            height: `${box.hPct}%`,
                          }}
                          className={`absolute rounded border-2 transition-opacity duration-300 ${
                            active
                              ? 'border-blue-600 bg-blue-500/15 opacity-100'
                              : 'border-transparent opacity-0'
                          }`}
                        >
                          <span className="absolute -top-5 left-0 rounded bg-blue-700 px-1.5 py-0.5 text-[10px] font-semibold text-white whitespace-nowrap">
                            {box.label}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                  <p className="max-w-2xl truncate text-xs text-slate-400">{spec.caption}</p>
                </>
              );
            })()}
          </div>
        ) : null}

        {spec.kind === 'equation' ? (
          <div className="w-full max-w-3xl space-y-4" dir="ltr">
            <div className="rounded-lg border border-slate-800 bg-slate-900/90 px-6 py-5 text-center overflow-x-auto">
              <div
                className="text-lg sm:text-xl text-white"
                // Safe KaTeX-generated math markup from local equation spec
                dangerouslySetInnerHTML={{ __html: renderedLatexHtml }}
              />
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              {spec.terms.map((term) => {
                const revealed = term.step <= currentStep;
                let termHtml = term.symbolLatex;
                try {
                  termHtml = katex.renderToString(term.symbolLatex, { throwOnError: false });
                } catch {
                  termHtml = term.symbolLatex;
                }
                return (
                  <div
                    key={term.symbolLatex}
                    className={`rounded-lg border p-3 transition-opacity duration-300 ${
                      revealed
                        ? 'border-blue-500/70 bg-blue-950/35 opacity-100'
                        : 'border-slate-800 bg-slate-900/40 opacity-35'
                    }`}
                  >
                    <div
                      className="text-sm text-blue-300"
                      dangerouslySetInnerHTML={{ __html: termHtml }}
                    />
                    <p className="mt-1.5 text-xs text-slate-200 leading-relaxed">
                      {term.meaning}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>
        ) : null}
      </div>

      {/* Bottom Caption Overlay with Measured Scrim */}
      {showCaptions && (
        <div className="bg-gradient-to-t from-black/90 via-black/75 to-transparent px-6 py-4">
          <p className="mx-auto max-w-3xl text-center text-sm sm:text-base font-medium leading-relaxed text-white">
            {captionText}
          </p>
        </div>
      )}
    </div>
  );
}
