import katex from 'katex';
import {
  ArrowLeftRight,
  ChevronLeft,
  ChevronRight,
  Eraser,
  NotebookPen,
  PanelLeft,
  PenTool,
  Play,
  Trash2,
  Undo2,
  ZoomIn,
  ZoomOut,
} from 'lucide-react';
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import {
  ClarificationSource,
  DocumentModel,
  QAResponse,
  ResearchNote,
  ResearchSketch,
  SketchStroke,
  StoryboardScene,
  VideoArtifact,
} from '../types.ts';

interface ApplePreviewReaderProps {
  document: DocumentModel;
  video: VideoArtifact;
  initialNotes?: ResearchNote[];
  initialSketches?: ResearchSketch[];
  isShareViewer?: boolean;
  onAnnotationsUpdated?: () => void;
  onJumpToVideoScene: (seconds: number) => void;
}

interface ArtifactCardItem {
  id: string;
  kind: 'scene' | 'clarification' | 'sentence';
  citationKey: string;
  allCitations: string[];
  title: string;
  subtitle: string;
  body: string;
  badgeText?: string;
  badgeTone?: 'amber' | 'red' | 'blue' | 'emerald';
  sceneSeconds?: number;
  scene?: StoryboardScene;
  clarification?: ClarificationSource;
}

interface ArrowCoords {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  label: string;
  visible: boolean;
}

const NOTE_COLOR_STYLES: Record<ResearchNote['colorTag'], { card: string; swatch: string; label: string }> = {
  amber: {
    card: 'border-amber-300 bg-amber-50/70',
    swatch: 'bg-amber-400',
    label: 'Amber',
  },
  blue: {
    card: 'border-blue-300 bg-blue-50/70',
    swatch: 'bg-blue-600',
    label: 'Cobalt',
  },
  emerald: {
    card: 'border-emerald-300 bg-emerald-50/70',
    swatch: 'bg-emerald-600',
    label: 'Emerald',
  },
  slate: {
    card: 'border-slate-300 bg-slate-50',
    swatch: 'bg-slate-700',
    label: 'Slate',
  },
};

const SKETCH_COLORS = [
  { hex: '#1d4ed8', label: 'Cobalt Blue' },
  { hex: '#d97706', label: 'Amber' },
  { hex: '#059669', label: 'Emerald' },
  { hex: '#0f172a', label: 'Ink Black' },
];

/**
 * Maps external clarification sources to the document citation keys they clarify.
 */
function clarificationDocLinks(c: ClarificationSource, doc: DocumentModel): string[] {
  const firstFallback = doc.paragraphs[0]?.citationKey ?? 'doc:p1/sec-intro';
  const hasCite = (key: string) =>
    doc.paragraphs.some((p) => p.citationKey === key) ||
    doc.tables.some((t) => t.citationKey === key);

  if (c.hardPartId === 'hp-orographic' && hasCite('doc:p1/sec-intro')) {
    return ['doc:p1/sec-intro'];
  }
  if (c.hardPartId === 'hp-csi' && hasCite('doc:p6/sec-results')) {
    return ['doc:p6/sec-results', ...(hasCite('doc:p5/table-1') ? ['doc:p5/table-1'] : [])];
  }
  if (c.hardPartId === 'hp-teleconnection' && hasCite('doc:p3/sec-arch')) {
    return c.contradictsPaper && hasCite('doc:p7/sec-limits')
      ? ['doc:p7/sec-limits', 'doc:p3/sec-arch']
      : ['doc:p3/sec-arch'];
  }

  const termLower = c.term.toLowerCase();
  const matched = doc.paragraphs.find((p) => p.text.toLowerCase().includes(termLower));
  return [matched?.citationKey ?? firstFallback];
}

export function ApplePreviewReader({
  document: doc,
  video,
  initialNotes = [],
  initialSketches = [],
  isShareViewer = false,
  onAnnotationsUpdated,
  onJumpToVideoScene,
}: ApplePreviewReaderProps) {
  const defaultCitationKey =
    doc.tables[0]?.citationKey ?? doc.paragraphs[0]?.citationKey ?? 'doc:p1/sec-intro';
  const defaultPage = doc.tables[0]?.page ?? doc.paragraphs[0]?.page ?? 1;

  const [showThumbnails, setShowThumbnails] = useState(true);
  const [zoomPct, setZoomPct] = useState(100);
  const [scopeFilter, setScopeFilter] = useState<'linked' | 'all'>('all');
  const [inspectorTab, setInspectorTab] = useState<'artifacts' | 'notes' | 'qa'>('artifacts');

  const [activeCitationKey, setActiveCitationKey] = useState<string>(defaultCitationKey);
  const [activeCardId, setActiveCardId] = useState<string>('');
  const [activePage, setActivePage] = useState<number>(defaultPage);

  // Notes & Sketches state
  const [notes, setNotes] = useState<ResearchNote[]>(initialNotes);
  const [sketches, setSketches] = useState<ResearchSketch[]>(initialSketches);
  const [noteTitle, setNoteTitle] = useState('');
  const [noteBody, setNoteBody] = useState('');
  const [noteColor, setNoteColor] = useState<ResearchNote['colorTag']>('amber');
  const [savingNote, setSavingNote] = useState(false);
  const [annotationError, setAnnotationError] = useState<string | null>(null);

  // Freehand Sketchpad state
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [sketchTitle, setSketchTitle] = useState('');
  const [inkColor, setInkColor] = useState('#1d4ed8');
  const [inkWidth, setInkWidth] = useState(2.5);
  const [strokes, setStrokes] = useState<SketchStroke[]>([]);
  const activeStrokeRef = useRef<SketchStroke | null>(null);
  const isDrawingRef = useRef(false);
  const [savingSketch, setSavingSketch] = useState(false);

  // Q&A state inside reader
  const [qaInput, setQaInput] = useState('');
  const [qaLoading, setQaLoading] = useState(false);
  const [qaHistory, setQaHistory] = useState<QAResponse[]>([]);
  const [imgFailed, setImgFailed] = useState<Record<string, boolean>>({});

  // Refs for calculating visible connecting arrow coordinates
  const splitContainerRef = useRef<HTMLDivElement | null>(null);
  const docScrollRef = useRef<HTMLDivElement | null>(null);
  const panelScrollRef = useRef<HTMLDivElement | null>(null);
  const docAnchorRefs = useRef<Record<string, HTMLElement | null>>({});
  const cardRefs = useRef<Record<string, HTMLElement | null>>({});
  const pageRefs = useRef<Record<number, HTMLElement | null>>({});

  const [arrow, setArrow] = useState<ArrowCoords>({
    x1: 0,
    y1: 0,
    x2: 0,
    y2: 0,
    label: '',
    visible: false,
  });

  // Sync notes/sketches and reset active anchors when switching documents
  useEffect(() => {
    setNotes(initialNotes);
    setSketches(initialSketches);
  }, [initialNotes, initialSketches]);

  useEffect(() => {
    docAnchorRefs.current = {};
    cardRefs.current = {};
    setActiveCitationKey(defaultCitationKey);
    setActivePage(defaultPage);
    setActiveCardId('');
    setQaHistory([]);
    setStrokes([]);
  }, [doc.id, defaultCitationKey, defaultPage]);

  // Redraw HTML5 canvas whenever strokes change or tab opens
  const redrawCanvas = useCallback(
    (strokeList: SketchStroke[], liveStroke?: SketchStroke | null) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      ctx.clearRect(0, 0, canvas.width, canvas.height);

      const allToDraw = liveStroke ? [...strokeList, liveStroke] : strokeList;
      for (const stroke of allToDraw) {
        if (stroke.points.length === 0) continue;
        ctx.save();
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        ctx.beginPath();
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
        if (stroke.points.length === 1) {
          ctx.lineTo(stroke.points[0].x + 0.5, stroke.points[0].y + 0.5);
        } else {
          for (let i = 1; i < stroke.points.length; i++) {
            ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
          }
        }
        ctx.stroke();
        ctx.restore();
      }
    },
    []
  );

  useEffect(() => {
    if (inspectorTab === 'notes') {
      requestAnimationFrame(() => redrawCanvas(strokes, activeStrokeRef.current));
    }
  }, [inspectorTab, strokes, redrawCanvas]);

  function getCanvasPoint(e: React.PointerEvent<HTMLCanvasElement>): { x: number; y: number } {
    const canvas = canvasRef.current!;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / Math.max(1, rect.width);
    const scaleY = canvas.height / Math.max(1, rect.height);
    return {
      x: Math.max(0, Math.min(canvas.width, (e.clientX - rect.left) * scaleX)),
      y: Math.max(0, Math.min(canvas.height, (e.clientY - rect.top) * scaleY)),
    };
  }

  function handlePointerDown(e: React.PointerEvent<HTMLCanvasElement>) {
    e.currentTarget.setPointerCapture(e.pointerId);
    const pt = getCanvasPoint(e);
    isDrawingRef.current = true;
    activeStrokeRef.current = { color: inkColor, width: inkWidth, points: [pt] };
    redrawCanvas(strokes, activeStrokeRef.current);
  }

  function handlePointerMove(e: React.PointerEvent<HTMLCanvasElement>) {
    if (!isDrawingRef.current || !activeStrokeRef.current) return;
    const pt = getCanvasPoint(e);
    activeStrokeRef.current.points.push(pt);
    redrawCanvas(strokes, activeStrokeRef.current);
  }

  function handlePointerUp() {
    if (!isDrawingRef.current || !activeStrokeRef.current) return;
    isDrawingRef.current = false;
    const finished = activeStrokeRef.current;
    activeStrokeRef.current = null;
    if (finished.points.length > 0) {
      setStrokes((prev) => [...prev, finished]);
    }
  }

  // Group all document elements by page number
  const pages = useMemo(() => {
    const pageSet = new Set<number>();
    doc.paragraphs.forEach((p) => pageSet.add(p.page));
    doc.figures.forEach((f) => pageSet.add(f.page));
    doc.tables.forEach((t) => pageSet.add(t.page));
    doc.equations.forEach((e) => pageSet.add(e.page));
    const sorted = Array.from(pageSet).sort((a, b) => a - b);
    return sorted.map((pageNum) => ({
      pageNum,
      paragraphs: doc.paragraphs.filter((p) => p.page === pageNum),
      figures: doc.figures.filter((f) => f.page === pageNum),
      tables: doc.tables.filter((t) => t.page === pageNum),
      equations: doc.equations.filter((e) => e.page === pageNum),
    }));
  }, [doc]);

  // Count notes + sketches per citation key for margin badges on document spans
  const annotationCountsByCite = useMemo(() => {
    const map: Record<string, { notes: number; sketches: number }> = {};
    for (const n of notes) {
      map[n.citationKey] = map[n.citationKey] ?? { notes: 0, sketches: 0 };
      map[n.citationKey].notes += 1;
    }
    for (const sk of sketches) {
      map[sk.citationKey] = map[sk.citationKey] ?? { notes: 0, sketches: 0 };
      map[sk.citationKey].sketches += 1;
    }
    return map;
  }, [notes, sketches]);

  // Build unified artifact & clarification cards linked to document citations
  const allCards = useMemo<ArtifactCardItem[]>(() => {
    const items: ArtifactCardItem[] = [];
    const fallbackCite = doc.paragraphs[0]?.citationKey ?? 'doc:p1/sec-intro';

    for (const scene of video.scenes) {
      const primaryCite = scene.citations.find((c) => c.startsWith('doc:')) ?? scene.citations[0] ?? fallbackCite;
      items.push({
        id: `art-scene-${scene.id}`,
        kind: 'scene',
        citationKey: primaryCite,
        allCitations: scene.citations,
        title: scene.translatedChapterTitle || scene.chapterTitle,
        subtitle: `Generated ${scene.visualSpec.kind.toUpperCase()} artifact · Scene ${scene.order} (${scene.durationSeconds}s)`,
        body: scene.translatedNarration || scene.narration,
        badgeText:
          scene.visualSpec.kind === 'chart'
            ? '100% Table-Verified Chart'
            : scene.visualSpec.kind === 'equation'
              ? 'Term-by-Term KaTeX'
              : scene.visualSpec.kind === 'figure'
                ? 'Highlighted Figure'
                : scene.visualSpec.kind === 'diagram'
                  ? 'Animated 2D Flow'
                  : 'Narrated Summary',
        badgeTone: 'blue',
        sceneSeconds: scene.startSeconds,
        scene,
      });
    }

    for (const c of video.clarifications) {
      const docTargets = clarificationDocLinks(c, doc);
      items.push({
        id: `art-clar-${c.id}`,
        kind: 'clarification',
        citationKey: docTargets[0],
        allCitations: [c.url, ...docTargets],
        title: c.title,
        subtitle: `Tier ${c.tier} Clarification · ${c.providerName} (${c.year})`,
        body: `“${c.quote}”`,
        badgeText:
          c.viewLabel === 'Differing view'
            ? 'Differing view'
            : c.confidenceLabel === 'lower confidence'
              ? 'Lower confidence'
              : `Tier ${c.tier} Verified`,
        badgeTone:
          c.viewLabel === 'Differing view'
            ? 'red'
            : c.confidenceLabel === 'lower confidence'
              ? 'amber'
              : 'emerald',
        clarification: c,
      });
    }

    return items;
  }, [video.scenes, video.clarifications, doc]);

  const visibleCards = useMemo(() => {
    if (scopeFilter === 'all') return allCards;
    return allCards.filter((card) => card.allCitations.includes(activeCitationKey));
  }, [allCards, scopeFilter, activeCitationKey]);

  useEffect(() => {
    if (inspectorTab === 'artifacts') {
      if (!activeCardId || !visibleCards.some((c) => c.id === activeCardId)) {
        const matching =
          visibleCards.find((c) => c.allCitations.includes(activeCitationKey)) ??
          visibleCards[0];
        if (matching) {
          setActiveCardId(matching.id);
        }
      }
    }
  }, [visibleCards, activeCardId, activeCitationKey, inspectorTab]);

  const updateArrow = useCallback(() => {
    const container = splitContainerRef.current;
    if (!container) return;

    const targetEl = docAnchorRefs.current[activeCitationKey];
    const sourceEl = cardRefs.current[activeCardId];

    if (!targetEl || !sourceEl) {
      setArrow((prev) => (prev.visible ? { ...prev, visible: false } : prev));
      return;
    }

    const cRect = container.getBoundingClientRect();
    const sRect = sourceEl.getBoundingClientRect();
    const tRect = targetEl.getBoundingClientRect();

    const docPaneRect = docScrollRef.current?.getBoundingClientRect();
    const panelPaneRect = panelScrollRef.current?.getBoundingClientRect();

    const targetInView =
      !docPaneRect ||
      (tRect.bottom >= docPaneRect.top + 8 && tRect.top <= docPaneRect.bottom - 8);
    const sourceInView =
      !panelPaneRect ||
      (sRect.bottom >= panelPaneRect.top + 8 && sRect.top <= panelPaneRect.bottom - 8);

    if (!targetInView || !sourceInView) {
      setArrow((prev) => (prev.visible ? { ...prev, visible: false } : prev));
      return;
    }

    const x1 = sRect.left - cRect.left;
    const y1 = sRect.top + Math.min(28, sRect.height / 2) - cRect.top;
    const x2 = tRect.right - cRect.left + 4;
    const y2 = tRect.top + Math.min(32, tRect.height / 2) - cRect.top;

    setArrow({
      x1,
      y1,
      x2,
      y2,
      label: activeCitationKey,
      visible: true,
    });
  }, [activeCitationKey, activeCardId]);

  useLayoutEffect(() => {
    const raf = requestAnimationFrame(updateArrow);
    return () => cancelAnimationFrame(raf);
  }, [updateArrow, zoomPct, showThumbnails, scopeFilter, inspectorTab, qaHistory, notes, sketches]);

  useEffect(() => {
    const onResize = () => requestAnimationFrame(updateArrow);
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, [updateArrow]);

  function selectDocumentSpan(citationKey: string, pageNum: number) {
    setActiveCitationKey(citationKey);
    setActivePage(pageNum);

    if (inspectorTab === 'notes') {
      const noteMatch = notes.find((n) => n.citationKey === citationKey);
      const sketchMatch = sketches.find((sk) => sk.citationKey === citationKey);
      const targetId = noteMatch ? `note-${noteMatch.id}` : sketchMatch ? `sketch-${sketchMatch.id}` : '';
      if (targetId) {
        setActiveCardId(targetId);
        setTimeout(() => {
          cardRefs.current[targetId]?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
          setTimeout(updateArrow, 260);
        }, 40);
      }
      return;
    }

    const match = allCards.find((c) => c.allCitations.includes(citationKey));
    if (match) {
      setActiveCardId(match.id);
      setTimeout(() => {
        cardRefs.current[match.id]?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        setTimeout(updateArrow, 260);
      }, 40);
    }
  }

  function selectArtifactCard(card: ArtifactCardItem) {
    setActiveCardId(card.id);
    const targetCite =
      card.allCitations.find((c) => c.startsWith('doc:') && docAnchorRefs.current[c]) ??
      card.citationKey;
    if (targetCite.startsWith('doc:')) {
      setActiveCitationKey(targetCite);
      const targetEl = docAnchorRefs.current[targetCite];
      if (targetEl) {
        targetEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
        setTimeout(updateArrow, 320);
      }
    }
  }

  function focusLinkedAnnotation(cardId: string, citationKey: string, pageNum: number) {
    setActiveCardId(cardId);
    setActiveCitationKey(citationKey);
    setActivePage(pageNum);
    const targetEl = docAnchorRefs.current[citationKey];
    if (targetEl) {
      targetEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
      setTimeout(updateArrow, 320);
    }
  }

  function scrollToPage(pageNum: number) {
    setActivePage(pageNum);
    pageRefs.current[pageNum]?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setTimeout(updateArrow, 320);
  }

  async function handleSaveNote(e: React.FormEvent) {
    e.preventDefault();
    if (!noteBody.trim()) return;
    setAnnotationError(null);
    setSavingNote(true);
    try {
      const res = await fetch(`/api/documents/${doc.id}/notes`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: noteTitle.trim() || `Note on ${activeCitationKey}`,
          body: noteBody.trim(),
          citationKey: activeCitationKey,
          page: activePage,
          colorTag: noteColor,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Could not save note.');
      setNotes((prev) => [data.note, ...prev]);
      setNoteTitle('');
      setNoteBody('');
      setActiveCardId(`note-${data.note.id}`);
      onAnnotationsUpdated?.();
    } catch (err) {
      setAnnotationError(err instanceof Error ? err.message : 'Save failed.');
    } finally {
      setSavingNote(false);
    }
  }

  async function handleDeleteNote(noteId: string) {
    const res = await fetch(`/api/documents/${doc.id}/notes/${noteId}`, { method: 'DELETE' });
    if (res.ok) {
      setNotes((prev) => prev.filter((n) => n.id !== noteId));
      onAnnotationsUpdated?.();
    }
  }

  async function handleSaveSketch() {
    if (strokes.length === 0) {
      setAnnotationError('Draw at least one stroke on the sketch pad before saving.');
      return;
    }
    setAnnotationError(null);
    setSavingSketch(true);
    try {
      const res = await fetch(`/api/documents/${doc.id}/sketches`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: sketchTitle.trim() || `Sketch (${activeCitationKey})`,
          citationKey: activeCitationKey,
          page: activePage,
          width: 360,
          height: 180,
          strokes,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Could not save sketch.');
      setSketches((prev) => [data.sketch, ...prev]);
      setStrokes([]);
      setSketchTitle('');
      setActiveCardId(`sketch-${data.sketch.id}`);
      onAnnotationsUpdated?.();
    } catch (err) {
      setAnnotationError(err instanceof Error ? err.message : 'Sketch save failed.');
    } finally {
      setSavingSketch(false);
    }
  }

  async function handleDeleteSketch(sketchId: string) {
    const res = await fetch(`/api/documents/${doc.id}/sketches/${sketchId}`, { method: 'DELETE' });
    if (res.ok) {
      setSketches((prev) => prev.filter((sk) => sk.id !== sketchId));
      onAnnotationsUpdated?.();
    }
  }

  async function askQuestion(qText?: string) {
    const q = (qText ?? qaInput).trim();
    if (!q) return;
    setQaLoading(true);
    if (!qText) setQaInput('');
    try {
      const res = await fetch(`/api/videos/${video.id}/qa`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: q }),
      });
      const data = (await res.json()) as QAResponse;
      setQaHistory((prev) => [data, ...prev]);

      const firstDocCite = data.sentences
        .flatMap((s) => s.citations)
        .find((c) => c.startsWith('doc:'));
      if (firstDocCite) {
        setActiveCitationKey(firstDocCite);
        setActiveCardId(`qa-ans-0`);
        setTimeout(() => {
          docAnchorRefs.current[firstDocCite]?.scrollIntoView({
            behavior: 'smooth',
            block: 'center',
          });
          setTimeout(updateArrow, 350);
        }, 60);
      }
    } finally {
      setQaLoading(false);
    }
  }

  const suggestedQuestions = useMemo(() => {
    if (doc.id === 'doc_monsoon_2025') {
      return [
        'What is MonsoonFormer 5-day RMSE compared to Full-Attention?',
        'What is the limitation beyond day 7 and what does Rao et al. say?',
        'What was the GDP growth rate of Brazil in 1994?',
      ];
    }
    const firstSec = doc.sections[0]?.title ?? 'Introduction';
    const questions = [
      `What are the main findings in ${firstSec}?`,
      doc.tables[0]
        ? `What values are reported in ${doc.tables[0].label}?`
        : `What limitations or challenges are noted in ${doc.title}?`,
      'What was the GDP growth rate of Brazil in 1994?',
    ];
    return questions;
  }, [doc]);

  const bezierPath = useMemo(() => {
    if (!arrow.visible) return '';
    const dx = Math.abs(arrow.x1 - arrow.x2);
    const offset = Math.max(48, dx * 0.42);
    const cx1 = arrow.x1 - offset;
    const cy1 = arrow.y1;
    const cx2 = arrow.x2 + offset;
    const cy2 = arrow.y2;
    return `M ${arrow.x1} ${arrow.y1} C ${cx1} ${cy1}, ${cx2} ${cy2}, ${arrow.x2} ${arrow.y2}`;
  }, [arrow]);

  const midX = (arrow.x1 + arrow.x2) / 2;
  const midY = (arrow.y1 + arrow.y2) / 2;

  function renderSpanBadge(citationKey: string) {
    const counts = annotationCountsByCite[citationKey];
    if (!counts) return null;
    const parts: string[] = [];
    if (counts.notes > 0) parts.push(`${counts.notes} ${counts.notes === 1 ? 'note' : 'notes'}`);
    if (counts.sketches > 0) parts.push(`${counts.sketches} ${counts.sketches === 1 ? 'sketch' : 'sketches'}`);
    return (
      <span className="font-mono text-[10px] font-medium text-amber-800">
        · {parts.join(' · ')}
      </span>
    );
  }

  return (
    <div className="rounded-xl border border-slate-300 bg-[#ECEEF1] shadow-sm overflow-hidden">
      {/* Apple Preview-Style Unified Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-300/80 bg-[#F6F7F9] px-4 py-2.5 text-xs">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setShowThumbnails((s) => !s)}
            aria-pressed={showThumbnails}
            className={`inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1.5 font-medium transition-colors ${
              showThumbnails
                ? 'border-slate-300 bg-white text-slate-900 shadow-2xs'
                : 'border-transparent text-slate-600 hover:bg-slate-200/70'
            }`}
          >
            <PanelLeft className="h-3.5 w-3.5" />
            Thumbnails
          </button>

          <div className="h-4 w-px bg-slate-300 mx-1" aria-hidden="true" />

          <button
            type="button"
            aria-label="Previous page"
            onClick={() => {
              const idx = pages.findIndex((p) => p.pageNum === activePage);
              if (idx > 0) scrollToPage(pages[idx - 1].pageNum);
            }}
            className="rounded-md p-1.5 text-slate-700 hover:bg-slate-200/70"
          >
            <ChevronLeft className="h-4 w-4" />
          </button>
          <span className="font-mono text-xs tabular-nums text-slate-700">
            Page {activePage} of {pages[pages.length - 1]?.pageNum ?? 1}
          </span>
          <button
            type="button"
            aria-label="Next page"
            onClick={() => {
              const idx = pages.findIndex((p) => p.pageNum === activePage);
              if (idx >= 0 && idx < pages.length - 1) scrollToPage(pages[idx + 1].pageNum);
            }}
            className="rounded-md p-1.5 text-slate-700 hover:bg-slate-200/70"
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>

        {/* Center Title & Active Link Indicator */}
        <div className="hidden xl:flex items-center gap-2 text-slate-600 max-w-md truncate">
          <ArrowLeftRight className="h-3.5 w-3.5 text-blue-700 shrink-0" />
          <span className="truncate font-medium text-slate-800">{doc.title}</span>
        </div>

        {/* Right Quick Annotate & Zoom Controls */}
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setInspectorTab('notes')}
            className={`inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1.5 text-xs font-medium transition-colors ${
              inspectorTab === 'notes'
                ? 'border-blue-700 bg-blue-50 text-blue-800'
                : 'border-slate-300 bg-white text-slate-700 hover:bg-slate-50'
            }`}
          >
            <NotebookPen className="h-3.5 w-3.5" />
            Notes &amp; Sketch ({notes.length + sketches.length})
          </button>

          <div className="h-4 w-px bg-slate-300 mx-0.5" aria-hidden="true" />

          <button
            type="button"
            aria-label="Zoom out"
            onClick={() => setZoomPct((z) => Math.max(85, z - 10))}
            className="rounded-md border border-slate-300 bg-white p-1.5 text-slate-700 hover:bg-slate-50"
          >
            <ZoomOut className="h-3.5 w-3.5" />
          </button>
          <span className="font-mono text-xs tabular-nums text-slate-700 w-10 text-center">
            {zoomPct}%
          </span>
          <button
            type="button"
            aria-label="Zoom in"
            onClick={() => setZoomPct((z) => Math.min(115, z + 10))}
            className="rounded-md border border-slate-300 bg-white p-1.5 text-slate-700 hover:bg-slate-50"
          >
            <ZoomIn className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>

      {/* Main Split Workspace with Live Connecting Arrow SVG Overlay */}
      <div
        ref={splitContainerRef}
        className="relative flex flex-col lg:flex-row h-[760px] overflow-hidden"
      >
        {/* Dynamic Connecting Arrow Overlay */}
        <svg
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 z-20 hidden lg:block h-full w-full"
        >
          <defs>
            <marker
              id="drishya-connector-arrow"
              viewBox="0 0 10 10"
              refX="8"
              refY="5"
              markerWidth="7"
              markerHeight="7"
              orient="auto-start-reverse"
            >
              <path d="M 0 1.5 L 9 5 L 0 8.5 z" fill="#1d4ed8" />
            </marker>
          </defs>
          {arrow.visible && (
            <g>
              <path
                d={bezierPath}
                fill="none"
                stroke="#ffffff"
                strokeWidth="5"
                strokeOpacity="0.85"
              />
              <path
                d={bezierPath}
                fill="none"
                stroke="#1d4ed8"
                strokeWidth="2.25"
                markerEnd="url(#drishya-connector-arrow)"
              />
              <circle cx={arrow.x1} cy={arrow.y1} r="4.5" fill="#1d4ed8" stroke="#ffffff" strokeWidth="1.5" />
              <g transform={`translate(${midX}, ${midY})`}>
                <rect
                  x="-54"
                  y="-11"
                  width="108"
                  height="22"
                  rx="4"
                  fill="#1e3a8a"
                  stroke="#ffffff"
                  strokeWidth="1"
                />
                <text
                  x="0"
                  y="3.5"
                  textAnchor="middle"
                  fill="#ffffff"
                  fontSize="10"
                  fontFamily="IBM Plex Mono, monospace"
                >
                  {arrow.label.slice(0, 16)}
                </text>
              </g>
            </g>
          )}
        </svg>

        {/* Left Thumbnail Rail (Apple Preview Sidebar) */}
        {showThumbnails && (
          <aside
            aria-label="Document pages"
            className="hidden md:flex w-40 shrink-0 flex-col gap-3 overflow-y-auto border-r border-slate-300/80 bg-[#F1F3F5] p-3"
          >
            {pages.map((p) => {
              const isCurrent = p.pageNum === activePage;
              const pageNotesCount = notes.filter((n) => n.page === p.pageNum).length;
              const pageSketchesCount = sketches.filter((sk) => sk.page === p.pageNum).length;
              return (
                <button
                  key={p.pageNum}
                  type="button"
                  onClick={() => scrollToPage(p.pageNum)}
                  className="group flex flex-col items-center gap-1.5 text-left focus-visible:outline-2 focus-visible:outline-blue-700"
                >
                  <div
                    className={`w-full aspect-[8.5/11] rounded border bg-white p-2 text-[7px] leading-tight text-slate-500 overflow-hidden transition-all ${
                      isCurrent
                        ? 'border-blue-700 ring-2 ring-blue-600/30'
                        : 'border-slate-300 group-hover:border-slate-400'
                    }`}
                  >
                    <div className="font-semibold text-slate-800 truncate">
                      {p.paragraphs[0]?.sectionTitle || `Page ${p.pageNum}`}
                    </div>
                    <div className="mt-1 space-y-0.5 opacity-75">
                      {p.paragraphs.slice(0, 2).map((para) => (
                        <p key={para.id} className="line-clamp-3">
                          {para.text}
                        </p>
                      ))}
                      {p.tables.length > 0 && (
                        <div className="mt-1 rounded bg-blue-50 px-1 py-0.5 font-mono text-[6px] text-blue-800">
                          {p.tables[0].label}
                        </div>
                      )}
                      {p.figures.length > 0 && (
                        <div className="mt-1 rounded bg-slate-100 px-1 py-0.5 font-mono text-[6px] text-slate-700">
                          {p.figures[0].label}
                        </div>
                      )}
                    </div>
                  </div>
                  <span
                    className={`font-mono text-[11px] tabular-nums ${
                      isCurrent ? 'font-semibold text-blue-800' : 'text-slate-600'
                    }`}
                  >
                    {p.pageNum}
                    {pageNotesCount + pageSketchesCount > 0
                      ? ` · ${pageNotesCount + pageSketchesCount} ann`
                      : ''}
                  </span>
                </button>
              );
            })}
          </aside>
        )}

        {/* Center Document Sheet Reader */}
        <div
          ref={docScrollRef}
          onScroll={() => requestAnimationFrame(updateArrow)}
          className="flex-1 overflow-y-auto notebook-dot-grid p-4 sm:p-6 space-y-6"
        >
          <div
            style={{
              transform: `scale(${zoomPct / 100})`,
              transformOrigin: 'top center',
            }}
            className="mx-auto max-w-[680px] space-y-6 pb-16"
          >
            {pages.map((page) => (
              <article
                key={page.pageNum}
                ref={(el) => {
                  pageRefs.current[page.pageNum] = el;
                }}
                aria-label={`Document page ${page.pageNum}`}
                className="rounded-sm border border-slate-300/90 bg-white px-8 py-9 shadow-sm space-y-5"
              >
                <div className="flex items-center justify-between border-b border-slate-100 pb-2 text-[11px] font-mono text-slate-400">
                  <span className="truncate">{doc.venue}</span>
                  <span className="tabular-nums">Page {page.pageNum}</span>
                </div>

                {page.pageNum === 1 && (
                  <header className="space-y-2 pb-2">
                    <h2 className="font-display text-xl font-bold leading-snug text-slate-900">
                      {doc.title}
                    </h2>
                    <div className="text-xs text-slate-600">
                      {doc.authors.join(', ')} · {doc.year} · {doc.license}
                    </div>
                  </header>
                )}

                {/* Paragraphs with interactive sentence/span highlighting */}
                {page.paragraphs.map((para) => {
                  const isTarget = activeCitationKey === para.citationKey;
                  return (
                    <div
                      key={para.id}
                      ref={(el) => {
                        if (!docAnchorRefs.current[para.citationKey]) {
                          docAnchorRefs.current[para.citationKey] = el;
                        }
                      }}
                      onClick={() => selectDocumentSpan(para.citationKey, page.pageNum)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          selectDocumentSpan(para.citationKey, page.pageNum);
                        }
                      }}
                      className={`group rounded-lg p-3 transition-all cursor-pointer ${
                        isTarget
                          ? 'bg-amber-100/80 ring-2 ring-blue-700'
                          : 'hover:bg-amber-50/70'
                      }`}
                    >
                      <div className="flex flex-wrap items-center justify-between gap-2 mb-1">
                        <span className="text-xs font-semibold text-slate-800">
                          {para.sectionTitle}
                        </span>
                        <span className="font-mono text-[10px] text-blue-700">
                          {para.citationKey}
                          {renderSpanBadge(para.citationKey)}
                        </span>
                      </div>
                      <p className="text-sm leading-relaxed text-slate-800">{para.text}</p>
                    </div>
                  );
                })}

                {/* Equations on this page */}
                {page.equations.map((eq) => {
                  const isTarget = activeCitationKey === eq.citationKey;
                  let html = eq.latex;
                  try {
                    html = katex.renderToString(eq.latex, {
                      throwOnError: false,
                      displayMode: true,
                    });
                  } catch {
                    html = eq.latex;
                  }
                  return (
                    <div
                      key={eq.id}
                      ref={(el) => {
                        docAnchorRefs.current[eq.citationKey] = el;
                      }}
                      onClick={() => selectDocumentSpan(eq.citationKey, page.pageNum)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          selectDocumentSpan(eq.citationKey, page.pageNum);
                        }
                      }}
                      className={`rounded-lg border p-4 transition-all cursor-pointer ${
                        isTarget
                          ? 'border-blue-700 bg-amber-50/70 ring-2 ring-blue-700'
                          : 'border-slate-200 bg-slate-50/60 hover:border-blue-300'
                      }`}
                    >
                      <div className="flex items-center justify-between text-xs mb-2">
                        <span className="font-semibold text-slate-900">{eq.label}</span>
                        <span className="font-mono text-[10px] text-blue-700">
                          {eq.citationKey}
                          {renderSpanBadge(eq.citationKey)}
                        </span>
                      </div>
                      <div
                        className="overflow-x-auto text-slate-900"
                        dangerouslySetInnerHTML={{ __html: html }}
                      />
                      <p className="mt-2 text-xs text-slate-600">{eq.description}</p>
                    </div>
                  );
                })}

                {/* Figures on this page */}
                {page.figures.map((fig) => {
                  const isTarget = activeCitationKey === fig.citationKey;
                  return (
                    <figure
                      key={fig.id}
                      ref={(el) => {
                        docAnchorRefs.current[fig.citationKey] = el;
                      }}
                      onClick={() => selectDocumentSpan(fig.citationKey, page.pageNum)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          selectDocumentSpan(fig.citationKey, page.pageNum);
                        }
                      }}
                      className={`rounded-lg border p-3 transition-all cursor-pointer space-y-2 ${
                        isTarget
                          ? 'border-blue-700 bg-amber-50/70 ring-2 ring-blue-700'
                          : 'border-slate-200 bg-white hover:border-blue-300'
                      }`}
                    >
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-semibold text-slate-900">{fig.label}</span>
                        <span className="font-mono text-[10px] text-blue-700">
                          {fig.citationKey}
                          {renderSpanBadge(fig.citationKey)}
                        </span>
                      </div>
                      {!imgFailed[fig.id] ? (
                        <img
                          src={fig.imageUrl}
                          alt={fig.caption}
                          referrerPolicy="no-referrer"
                          onError={() =>
                            setImgFailed((prev) => ({ ...prev, [fig.id]: true }))
                          }
                          className="w-full max-h-56 rounded border border-slate-200 object-contain bg-white"
                        />
                      ) : (
                        <div className="flex h-36 items-center justify-center rounded border border-slate-200 bg-slate-100 text-xs text-slate-600">
                          {fig.label} preview
                        </div>
                      )}
                      <figcaption className="text-xs text-slate-600 leading-relaxed">
                        {fig.caption}
                      </figcaption>
                    </figure>
                  );
                })}

                {/* Tables on this page */}
                {page.tables.map((tbl) => {
                  const isTarget = activeCitationKey === tbl.citationKey;
                  return (
                    <div
                      key={tbl.id}
                      ref={(el) => {
                        docAnchorRefs.current[tbl.citationKey] = el;
                      }}
                      onClick={() => selectDocumentSpan(tbl.citationKey, page.pageNum)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          selectDocumentSpan(tbl.citationKey, page.pageNum);
                        }
                      }}
                      className={`rounded-lg border p-3.5 transition-all cursor-pointer space-y-2 ${
                        isTarget
                          ? 'border-blue-700 bg-amber-50/70 ring-2 ring-blue-700'
                          : 'border-slate-200 bg-white hover:border-blue-300'
                      }`}
                    >
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-semibold text-slate-900">{tbl.label}</span>
                        <span className="font-mono text-[10px] text-blue-700">
                          {tbl.citationKey}
                          {renderSpanBadge(tbl.citationKey)}
                        </span>
                      </div>
                      <p className="text-xs text-slate-600">{tbl.caption}</p>
                      <div className="overflow-x-auto">
                        <table className="w-full text-left text-xs tabular-nums">
                          <thead className="border-b border-slate-200 text-slate-500">
                            <tr>
                              {tbl.columns.map((col) => (
                                <th key={col} className="py-1.5 pr-3 font-medium">
                                  {col} {tbl.units[col] ? `(${tbl.units[col]})` : ''}
                                </th>
                              ))}
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-slate-100 text-slate-800">
                            {tbl.rows.map((row, rIdx) => (
                              <tr key={rIdx}>
                                {tbl.columns.map((col) => (
                                  <td key={col} className="py-1.5 pr-3 font-mono">
                                    {String(row[col] ?? '')}
                                  </td>
                                ))}
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  );
                })}
              </article>
            ))}
          </div>
        </div>

        {/* Right Inspector Panel: Artifacts, Notes & Sketches, & Grounded Q&A */}
        <aside className="w-full lg:w-[440px] xl:w-[480px] shrink-0 border-t lg:border-t-0 lg:border-l border-slate-300/80 bg-white flex flex-col">
          {/* Inspector Header & Scope Switcher */}
          <div className="border-b border-slate-200 p-3 space-y-2.5 bg-[#F9FAFB]">
            <div className="flex items-center rounded-lg bg-slate-200/70 p-0.5 text-xs gap-0.5">
              <button
                type="button"
                onClick={() => setInspectorTab('artifacts')}
                className={`flex-1 rounded-md px-2.5 py-1.5 font-semibold transition-colors whitespace-nowrap ${
                  inspectorTab === 'artifacts'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Artifacts &amp; Sources
              </button>
              <button
                type="button"
                onClick={() => setInspectorTab('notes')}
                className={`flex-1 rounded-md px-2.5 py-1.5 font-semibold transition-colors whitespace-nowrap ${
                  inspectorTab === 'notes'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Notes &amp; Sketches ({notes.length + sketches.length})
              </button>
              <button
                type="button"
                onClick={() => setInspectorTab('qa')}
                className={`rounded-md px-3 py-1.5 font-semibold transition-colors whitespace-nowrap ${
                  inspectorTab === 'qa'
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Ask Paper
              </button>
            </div>

            {inspectorTab === 'artifacts' && (
              <div className="flex items-center justify-between gap-2 text-xs">
                <span className="font-mono text-[11px] text-blue-800 truncate">
                  Target: {activeCitationKey}
                </span>
                <div className="flex items-center rounded-md border border-slate-200 bg-white p-0.5 shrink-0">
                  <button
                    type="button"
                    onClick={() => setScopeFilter('all')}
                    className={`rounded px-2 py-1 text-[11px] font-medium ${
                      scopeFilter === 'all'
                        ? 'bg-blue-700 text-white'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Full Paper ({allCards.length})
                  </button>
                  <button
                    type="button"
                    onClick={() => setScopeFilter('linked')}
                    className={`rounded px-2 py-1 text-[11px] font-medium ${
                      scopeFilter === 'linked'
                        ? 'bg-blue-700 text-white'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Linked Span
                  </button>
                </div>
              </div>
            )}

            {inspectorTab === 'notes' && (
              <div className="flex items-center justify-between gap-2 text-[11px] text-slate-600">
                <span className="font-mono text-blue-800 truncate">
                  Anchored to: {activeCitationKey} (Page {activePage})
                </span>
                <span className="text-slate-500 shrink-0">Click paper text to re-anchor</span>
              </div>
            )}
          </div>

          {/* Scrollable Cards Area */}
          <div
            ref={panelScrollRef}
            onScroll={() => requestAnimationFrame(updateArrow)}
            className="flex-1 overflow-y-auto p-4 space-y-4"
          >
            {inspectorTab === 'artifacts' &&
              (visibleCards.length === 0 ? (
                <div className="rounded-lg border border-slate-200 bg-slate-50 p-4 text-xs text-slate-600 space-y-2">
                  <p>No specific artifacts filtered exclusively to {activeCitationKey}.</p>
                  <button
                    type="button"
                    onClick={() => setScopeFilter('all')}
                    className="font-semibold text-blue-700 hover:underline"
                  >
                    Show all Full Paper artifacts &amp; clarifications
                  </button>
                </div>
              ) : (
                visibleCards.map((card) => {
                  const isActive = card.id === activeCardId;
                  const toneClass =
                    card.badgeTone === 'red'
                      ? 'text-red-700'
                      : card.badgeTone === 'amber'
                        ? 'text-amber-700'
                        : card.badgeTone === 'emerald'
                          ? 'text-emerald-700'
                          : 'text-blue-700';

                  return (
                    <div
                      key={card.id}
                      ref={(el) => {
                        cardRefs.current[card.id] = el;
                      }}
                      onClick={() => selectArtifactCard(card)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          selectArtifactCard(card);
                        }
                      }}
                      className={`rounded-xl border p-4 space-y-2 transition-all cursor-pointer ${
                        isActive
                          ? 'border-blue-700 bg-blue-50/40 ring-1 ring-blue-700'
                          : 'border-slate-200 bg-white hover:border-slate-300'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2 text-[11px]">
                        <span className={`font-semibold ${toneClass}`}>{card.badgeText}</span>
                        <span className="font-mono text-slate-500 truncate">
                          {card.citationKey}
                        </span>
                      </div>

                      <h3 className="text-sm font-semibold text-slate-900 leading-snug">
                        {card.title}
                      </h3>

                      <div className="text-[11px] text-slate-500">{card.subtitle}</div>

                      <p
                        dir={card.kind === 'scene' && video.languageDir === 'rtl' ? 'rtl' : 'ltr'}
                        className="text-xs text-slate-700 leading-relaxed"
                      >
                        {card.body}
                      </p>

                      {card.scene?.visualSpec.kind === 'chart' &&
                        card.scene.visualSpec.resolvedSeries && (
                          <div className="rounded-lg border border-slate-200 bg-slate-50 p-2.5 text-[11px] font-mono tabular-nums space-y-1">
                            {card.scene.visualSpec.resolvedSeries.map((row) => (
                              <div key={row.label} className="flex justify-between gap-2">
                                <span className="font-semibold text-slate-800">{row.label}</span>
                                <span className="text-slate-600">
                                  {Object.entries(row.values)
                                    .slice(0, 2)
                                    .map(([k, v]) => `${k}: ${v}`)
                                    .join(' · ')}
                                </span>
                              </div>
                            ))}
                          </div>
                        )}

                      <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
                        <div className="flex flex-wrap gap-2">
                          {card.allCitations.slice(0, 2).map((cit) => (
                            <span key={cit} className="font-mono text-[10px] text-blue-700">
                              [{cit}]
                            </span>
                          ))}
                        </div>
                        {card.sceneSeconds !== undefined && (
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              onJumpToVideoScene(card.sceneSeconds!);
                            }}
                            className="inline-flex items-center gap-1 rounded-md bg-blue-700 px-2.5 py-1 text-[11px] font-semibold text-white hover:bg-blue-800"
                          >
                            <Play className="h-3 w-3" />
                            Watch Scene
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })
              ))}

            {inspectorTab === 'notes' && (
              <div className="space-y-4">
                {annotationError && (
                  <div role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-800">
                    {annotationError}
                  </div>
                )}

                {!isShareViewer && (
                  <>
                    {/* Anchored Note Composer */}
                    <form
                      onSubmit={handleSaveNote}
                      className="rounded-xl border border-slate-200 bg-[#fbfcfe] p-3.5 space-y-2.5"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-900">
                          <NotebookPen className="h-3.5 w-3.5 text-blue-700" />
                          New Research Note
                        </div>
                        <div className="flex items-center gap-1">
                          {(['amber', 'blue', 'emerald', 'slate'] as const).map((tone) => (
                            <button
                              key={tone}
                              type="button"
                              aria-label={`Color tag ${NOTE_COLOR_STYLES[tone].label}`}
                              onClick={() => setNoteColor(tone)}
                              className={`h-4 w-4 rounded-sm ${NOTE_COLOR_STYLES[tone].swatch} ${
                                noteColor === tone ? 'ring-2 ring-offset-1 ring-slate-900' : 'opacity-65 hover:opacity-100'
                              }`}
                            />
                          ))}
                        </div>
                      </div>
                      <input
                        type="text"
                        aria-label="Note heading"
                        value={noteTitle}
                        onChange={(e) => setNoteTitle(e.target.value)}
                        placeholder={`Heading (linked to ${activeCitationKey})`}
                        className="w-full rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs text-slate-900 focus:border-blue-700 focus:outline-none"
                      />
                      <textarea
                        rows={3}
                        aria-label="Note body"
                        value={noteBody}
                        onChange={(e) => setNoteBody(e.target.value)}
                        placeholder="Write observation, hypothesis, or follow-up citation..."
                        className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs text-slate-900 focus:border-blue-700 focus:outline-none"
                      />
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-mono text-[10px] text-slate-500 truncate">
                          Anchor: {activeCitationKey}
                        </span>
                        <button
                          type="submit"
                          disabled={savingNote || !noteBody.trim()}
                          className="rounded-lg bg-blue-700 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-800 disabled:opacity-50"
                        >
                          {savingNote ? 'Saving...' : 'Save Note'}
                        </button>
                      </div>
                    </form>

                    {/* Interactive Freehand Sketchpad */}
                    <div className="rounded-xl border border-slate-200 bg-white p-3.5 space-y-2.5">
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-900">
                          <PenTool className="h-3.5 w-3.5 text-blue-700" />
                          Freehand Sketch Pad
                        </div>
                        <div className="flex items-center gap-1.5">
                          {SKETCH_COLORS.map((c) => (
                            <button
                              key={c.hex}
                              type="button"
                              aria-label={c.label}
                              onClick={() => setInkColor(c.hex)}
                              style={{ backgroundColor: c.hex }}
                              className={`h-4 w-4 rounded-sm ${
                                inkColor === c.hex ? 'ring-2 ring-offset-1 ring-slate-900' : 'opacity-70 hover:opacity-100'
                              }`}
                            />
                          ))}
                          <div className="h-3.5 w-px bg-slate-200 mx-0.5" aria-hidden="true" />
                          <button
                            type="button"
                            onClick={() => setInkWidth(2.5)}
                            className={`rounded px-1.5 py-0.5 font-mono text-[10px] ${
                              inkWidth <= 2.5 ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-700'
                            }`}
                          >
                            2px
                          </button>
                          <button
                            type="button"
                            onClick={() => setInkWidth(4.5)}
                            className={`rounded px-1.5 py-0.5 font-mono text-[10px] ${
                              inkWidth > 2.5 ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-700'
                            }`}
                          >
                            4px
                          </button>
                        </div>
                      </div>

                      <canvas
                        ref={canvasRef}
                        width={360}
                        height={180}
                        onPointerDown={handlePointerDown}
                        onPointerMove={handlePointerMove}
                        onPointerUp={handlePointerUp}
                        onPointerLeave={handlePointerUp}
                        aria-label="Freehand research sketch pad"
                        className="w-full h-[180px] rounded-lg border border-slate-300 notebook-dot-grid touch-none cursor-crosshair"
                      />

                      <div className="flex flex-wrap items-center gap-2">
                        <input
                          type="text"
                          aria-label="Sketch title"
                          value={sketchTitle}
                          onChange={(e) => setSketchTitle(e.target.value)}
                          placeholder="Sketch title (optional)"
                          className="flex-1 min-w-[120px] rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs text-slate-900 focus:border-blue-700 focus:outline-none"
                        />
                        <button
                          type="button"
                          onClick={() => setStrokes((prev) => prev.slice(0, -1))}
                          disabled={strokes.length === 0}
                          aria-label="Undo stroke"
                          className="inline-flex items-center gap-1 rounded-lg border border-slate-300 px-2 py-1.5 text-xs text-slate-700 hover:bg-slate-50 disabled:opacity-40"
                        >
                          <Undo2 className="h-3.5 w-3.5" />
                        </button>
                        <button
                          type="button"
                          onClick={() => setStrokes([])}
                          disabled={strokes.length === 0}
                          aria-label="Clear sketch"
                          className="inline-flex items-center gap-1 rounded-lg border border-slate-300 px-2 py-1.5 text-xs text-slate-700 hover:bg-slate-50 disabled:opacity-40"
                        >
                          <Eraser className="h-3.5 w-3.5" />
                        </button>
                        <button
                          type="button"
                          onClick={handleSaveSketch}
                          disabled={savingSketch || strokes.length === 0}
                          className="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white hover:bg-slate-800 disabled:opacity-50"
                        >
                          {savingSketch ? 'Saving...' : 'Save Sketch'}
                        </button>
                      </div>
                    </div>
                  </>
                )}

                {/* Saved Notes List */}
                <div className="space-y-2.5">
                  <div className="flex items-center justify-between text-xs font-semibold text-slate-700">
                    <span>Saved Notes ({notes.length})</span>
                    <span className="font-normal text-slate-500">Click card to point arrow</span>
                  </div>
                  {notes.length === 0 ? (
                    <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-500">
                      No notes yet. Click any span on the page and add a note above.
                    </div>
                  ) : (
                    notes.map((n) => {
                      const cardId = `note-${n.id}`;
                      const isActive = activeCardId === cardId;
                      return (
                        <div
                          key={n.id}
                          ref={(el) => {
                            cardRefs.current[cardId] = el;
                          }}
                          onClick={() => focusLinkedAnnotation(cardId, n.citationKey, n.page)}
                          role="button"
                          tabIndex={0}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' || e.key === ' ') {
                              e.preventDefault();
                              focusLinkedAnnotation(cardId, n.citationKey, n.page);
                            }
                          }}
                          className={`rounded-xl border p-3.5 space-y-1.5 cursor-pointer transition-all ${
                            NOTE_COLOR_STYLES[n.colorTag].card
                          } ${isActive ? 'ring-2 ring-blue-700' : 'hover:border-slate-400'}`}
                        >
                          <div className="flex items-center justify-between gap-2 text-[11px]">
                            <span className="font-mono text-blue-800">
                              Page {n.page} · {n.citationKey}
                            </span>
                            {!isShareViewer && (
                              <button
                                type="button"
                                aria-label={`Delete note ${n.title}`}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleDeleteNote(n.id);
                                }}
                                className="rounded p-1 text-slate-500 hover:bg-white/70 hover:text-red-700"
                              >
                                <Trash2 className="h-3.5 w-3.5" />
                              </button>
                            )}
                          </div>
                          <h4 className="text-xs font-semibold text-slate-900">{n.title}</h4>
                          <p className="text-xs text-slate-800 leading-relaxed whitespace-pre-wrap">
                            {n.body}
                          </p>
                        </div>
                      );
                    })
                  )}
                </div>

                {/* Saved Vector Sketches List */}
                <div className="space-y-2.5">
                  <div className="text-xs font-semibold text-slate-700">
                    Saved Vector Sketches ({sketches.length})
                  </div>
                  {sketches.length === 0 ? (
                    <div className="rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-500">
                      No sketches saved yet. Draw diagrams on the dot-grid canvas above.
                    </div>
                  ) : (
                    sketches.map((sk) => {
                      const cardId = `sketch-${sk.id}`;
                      const isActive = activeCardId === cardId;
                      return (
                        <div
                          key={sk.id}
                          ref={(el) => {
                            cardRefs.current[cardId] = el;
                          }}
                          onClick={() => focusLinkedAnnotation(cardId, sk.citationKey, sk.page)}
                          role="button"
                          tabIndex={0}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' || e.key === ' ') {
                              e.preventDefault();
                              focusLinkedAnnotation(cardId, sk.citationKey, sk.page);
                            }
                          }}
                          className={`rounded-xl border border-slate-200 bg-white p-3.5 space-y-2 cursor-pointer transition-all ${
                            isActive ? 'border-blue-700 ring-2 ring-blue-700' : 'hover:border-slate-300'
                          }`}
                        >
                          <div className="flex items-center justify-between gap-2 text-[11px]">
                            <span className="font-mono text-blue-800">
                              Page {sk.page} · {sk.citationKey}
                            </span>
                            {!isShareViewer && (
                              <button
                                type="button"
                                aria-label={`Delete sketch ${sk.title}`}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleDeleteSketch(sk.id);
                                }}
                                className="rounded p-1 text-slate-500 hover:bg-slate-100 hover:text-red-700"
                              >
                                <Trash2 className="h-3.5 w-3.5" />
                              </button>
                            )}
                          </div>
                          <h4 className="text-xs font-semibold text-slate-900">{sk.title}</h4>
                          <svg
                            viewBox={`0 0 ${sk.width} ${sk.height}`}
                            className="w-full h-auto rounded-lg border border-slate-200 notebook-dot-grid"
                          >
                            {sk.strokes.map((st, idx) => (
                              <polyline
                                key={idx}
                                fill="none"
                                stroke={st.color}
                                strokeWidth={st.width}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                points={st.points.map((pt) => `${pt.x},${pt.y}`).join(' ')}
                              />
                            ))}
                          </svg>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            )}

            {inspectorTab === 'qa' && (
              <div className="space-y-4">
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    askQuestion();
                  }}
                  className="space-y-2"
                >
                  <label htmlFor="reader-qa-input" className="block text-xs font-semibold text-slate-700">
                    Ask a question (highlights &amp; points arrow to exact answer span)
                  </label>
                  <div className="flex gap-2">
                    <input
                      id="reader-qa-input"
                      type="text"
                      value={qaInput}
                      onChange={(e) => setQaInput(e.target.value)}
                      placeholder="Ask from this paper..."
                      className="flex-1 rounded-lg border border-slate-300 px-3 py-2 text-xs text-slate-900 focus:border-blue-700 focus:outline-none"
                    />
                    <button
                      type="submit"
                      disabled={qaLoading}
                      className="rounded-lg bg-blue-700 px-3.5 py-2 text-xs font-semibold text-white hover:bg-blue-800 disabled:opacity-50"
                    >
                      {qaLoading ? '...' : 'Ask'}
                    </button>
                  </div>
                </form>

                <div className="flex flex-col gap-1.5">
                  {suggestedQuestions.map((q) => (
                    <button
                      key={q}
                      type="button"
                      onClick={() => askQuestion(q)}
                      className="text-left rounded-lg border border-slate-200 px-3 py-1.5 text-xs text-slate-700 hover:bg-slate-50"
                    >
                      {q}
                    </button>
                  ))}
                </div>

                {qaHistory.map((ans, idx) => (
                  <div
                    key={idx}
                    ref={(el) => {
                      if (idx === 0) cardRefs.current['qa-ans-0'] = el;
                    }}
                    className="rounded-xl border border-blue-200 bg-blue-50/40 p-3.5 space-y-2"
                  >
                    <div className="text-xs font-semibold text-slate-900">Q: {ans.question}</div>
                    {!ans.answered ? (
                      <p className="text-xs font-medium text-slate-700">{ans.refusalText}</p>
                    ) : (
                      <div className="space-y-2">
                        {ans.sentences.map((s, sIdx) => (
                          <div key={sIdx} className="text-xs text-slate-800 leading-relaxed space-y-1">
                            <p>{s.text}</p>
                            <div className="flex flex-wrap items-center gap-2">
                              {s.citations.map((cit) => (
                                <button
                                  key={cit}
                                  type="button"
                                  onClick={() => {
                                    if (cit.startsWith('doc:')) {
                                      setActiveCitationKey(cit);
                                      setActiveCardId(`qa-ans-0`);
                                      docAnchorRefs.current[cit]?.scrollIntoView({
                                        behavior: 'smooth',
                                        block: 'center',
                                      });
                                      setTimeout(updateArrow, 320);
                                    }
                                  }}
                                  className="font-mono text-[10px] font-semibold text-blue-700 underline"
                                >
                                  Point arrow to [{cit}]
                                </button>
                              ))}
                              {s.jumpToSeconds !== undefined && (
                                <button
                                  type="button"
                                  onClick={() => onJumpToVideoScene(s.jumpToSeconds!)}
                                  className="text-[11px] font-semibold text-emerald-700 hover:underline"
                                >
                                  Watch Scene
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
            )}
          </div>
        </aside>
      </div>
    </div>
  );
}
