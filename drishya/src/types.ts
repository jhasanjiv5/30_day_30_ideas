export type Depth = 'beginner' | 'student' | 'expert';
export type LengthTarget = '2min' | '5min' | '10min';
export type LanguageCode =
  | 'en'
  | 'hi'
  | 'bn'
  | 'mr'
  | 'ta'
  | 'te'
  | 'gu'
  | 'kn'
  | 'ml'
  | 'pa'
  | 'or'
  | 'ur';

export type LLMProviderName = 'mock' | 'gemini' | 'anthropic' | 'openai' | 'ollama';
export type TTSProviderName = 'mock' | 'cloud' | 'piper';

export interface LanguageInfo {
  code: LanguageCode;
  name: string;
  nativeName: string;
  dir: 'ltr' | 'rtl';
  capability: 'voice_and_captions' | 'captions_only';
  defaultVoice: string;
  piperVoice: string;
}

export interface DocumentModel {
  id: string;
  title: string;
  authors: string[];
  venue: string;
  year: number;
  license: string;
  sourceUrl?: string;
  sourceFormat: 'arxiv-latex' | 'pdf' | 'docx' | 'html' | 'fixture';
  ocrUsed: boolean;
  sections: Array<{ id: string; title: string; pageStart: number }>;
  paragraphs: Array<{
    id: string;
    sectionId: string;
    sectionTitle: string;
    page: number;
    text: string;
    citationKey: string;
  }>;
  figures: Array<{
    id: string;
    label: string;
    page: number;
    caption: string;
    imageUrl: string;
    citationKey: string;
  }>;
  tables: Array<{
    id: string;
    label: string;
    page: number;
    caption: string;
    columns: string[];
    units: Record<string, string>;
    rows: Array<Record<string, string | number>>;
    citationKey: string;
  }>;
  equations: Array<{
    id: string;
    label: string;
    page: number;
    latex: string;
    description: string;
    citationKey: string;
  }>;
  references: Array<{
    id: string;
    title: string;
    authors: string;
    year: number;
    doi?: string;
    arxivId?: string;
    url: string;
  }>;
}

export interface StoredDocument {
  id: string;
  ownerId: string;
  model: DocumentModel;
  createdAt: string;
  expiresAt: string;
  latestJobId?: string;
  latestVideoId?: string;
}

export interface ClarificationSource {
  id: string;
  hardPartId: string;
  term: string;
  tier: 1 | 2 | 3;
  providerName: string;
  title: string;
  url: string;
  year: number;
  relevanceScore: number;
  quote: string;
  confidenceLabel: 'high' | 'lower confidence';
  contradictsPaper: boolean;
  viewLabel?: 'Differing view';
}

export type VisualSpec =
  | {
      kind: 'diagram';
      title: string;
      nodes: Array<{ id: string; label: string; group: string; step: number }>;
      edges: Array<{ from: string; to: string; label?: string; step: number }>;
    }
  | {
      kind: 'chart';
      title: string;
      chartType: 'bar' | 'grouped-bar' | 'line';
      tableId: string;
      xColumn: string;
      yColumns: string[];
      highlightRow?: string;
      resolvedSeries?: Array<{ label: string; values: Record<string, number | string> }>;
    }
  | {
      kind: 'figure';
      title: string;
      figureId: string;
      caption: string;
      highlightBoxes: Array<{
        xPct: number;
        yPct: number;
        wPct: number;
        hPct: number;
        label: string;
        step: number;
      }>;
    }
  | {
      kind: 'equation';
      title: string;
      equationId: string;
      latex: string;
      terms: Array<{ symbolLatex: string; meaning: string; step: number }>;
    }
  | {
      kind: 'title' | 'takeaway';
      title: string;
      subtitle: string;
      bullets: string[];
      isAnalogy?: boolean;
    };

export interface StoryboardScene {
  id: string;
  order: number;
  arcPhase: 'why_it_matters' | 'background' | 'method' | 'results' | 'limitations' | 'whats_next';
  chapterTitle: string;
  translatedChapterTitle?: string;
  narration: string;
  translatedNarration?: string;
  sentences: Array<{
    id: string;
    text: string;
    translatedText?: string;
    citations: string[];
    isAnalogy?: boolean;
  }>;
  visualSpec: VisualSpec;
  citations: string[];
  durationSeconds: number;
  startSeconds: number;
}

export interface ChartAccuracyEntry {
  sceneId: string;
  tableId: string;
  tableLabel: string;
  verified: boolean;
  checkedCells: number;
  mismatches: string[];
}

export interface VideoArtifact {
  id: string;
  jobId: string;
  documentId: string;
  depth: Depth;
  lengthTarget: LengthTarget;
  language: LanguageCode;
  languageDir: 'ltr' | 'rtl';
  languageCapability: 'voice_and_captions' | 'captions_only';
  ttsVoice: string;
  ttsProvider: TTSProviderName;
  llmProvider: LLMProviderName;
  llmModel: string;
  mp4Url: string;
  vttUrl: string;
  audioUrl: string;
  durationSeconds: number;
  chapters: Array<{ title: string; startSeconds: number; endSeconds: number; sceneId: string }>;
  scenes: StoryboardScene[];
  clarifications: ClarificationSource[];
  chartAccuracyReport: ChartAccuracyEntry[];
  droppedUncitedSentences: number;
  numberGuardViolations: number;
  translationGuardVerified: boolean;
  createdAt: string;
}

export type JobStageName = 'ingest' | 'understand' | 'clarify' | 'plan' | 'translate' | 'render';

export interface StageTelemetry {
  stage: JobStageName;
  status: 'pending' | 'running' | 'completed' | 'failed';
  durationMs: number;
  provider: string;
  model: string;
  promptVersion: string;
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
  message: string;
  error?: string;
}

export interface JobRecord {
  id: string;
  documentId: string;
  ownerId: string;
  status: string;
  failedStage?: JobStageName;
  depth: Depth;
  lengthTarget: LengthTarget;
  language: LanguageCode;
  llmProvider: LLMProviderName;
  llmModel: string;
  ttsProvider: TTSProviderName;
  stages: StageTelemetry[];
  totalTokens: number;
  totalCostUsd: number;
  understand?: {
    claims: Array<{ id: string; statement: string; citationKey: string }>;
    methodSteps: Array<{ step: number; title: string; summary: string; citationKey: string }>;
    results: Array<{ metric: string; value: string; citationKey: string }>;
    limitations: Array<{ statement: string; citationKey: string }>;
    glossary: Array<{ term: string; definition: string; citationKey: string }>;
    hardParts: Array<{ id: string; term: string; reason: string; targetDepth: Depth }>;
  };
  clarifications?: ClarificationSource[];
  videoId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ResearchNote {
  id: string;
  documentId: string;
  citationKey: string;
  page: number;
  title: string;
  body: string;
  colorTag: 'amber' | 'blue' | 'emerald' | 'slate';
  createdAt: string;
  updatedAt: string;
}

export interface SketchStroke {
  color: string;
  width: number;
  points: Array<{ x: number; y: number }>;
}

export interface ResearchSketch {
  id: string;
  documentId: string;
  citationKey: string;
  page: number;
  title: string;
  width: number;
  height: number;
  strokes: SketchStroke[];
  createdAt: string;
}

export interface LibraryItem {
  document: StoredDocument;
  latestJob?: JobRecord;
  latestVideo?: VideoArtifact;
  notesCount?: number;
  sketchesCount?: number;
}

export interface WorkspaceSettings {
  ownerId: string;
  mockMode: boolean;
  llmProvider: LLMProviderName;
  llmModels: Record<LLMProviderName, string>;
  fallbackChain: LLMProviderName[];
  ttsProvider: TTSProviderName;
  retentionDays: number;
  searchProvider: 'fixture' | 'openalex+crossref+web';
  trainingOptOutConfirmed: boolean;
}

export interface AuditLogEntry {
  id: string;
  timestamp: string;
  actorId: string;
  action: string;
  resourceId: string;
  metadataRedacted: true;
  note: string;
}

export interface QAResponse {
  question: string;
  answered: boolean;
  refusalText?: string;
  sentences: Array<{
    text: string;
    citations: string[];
    jumpToSceneId?: string;
    jumpToSeconds?: number;
  }>;
  retrievedChunks: Array<{
    id: string;
    sourceType: 'document' | 'clarification';
    citationKey: string;
    title: string;
    snippet: string;
    rrfScore: number;
    tier?: 1 | 2 | 3;
    confidenceLabel?: 'high' | 'lower confidence';
    viewLabel?: 'Differing view';
    url?: string;
  }>;
}

export type ActiveScreen = 'library' | 'new' | 'job' | 'player' | 'settings';
