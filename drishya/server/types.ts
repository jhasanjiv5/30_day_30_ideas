import { z } from 'zod';

export const DepthSchema = z.enum(['beginner', 'student', 'expert']);
export type Depth = z.infer<typeof DepthSchema>;

export const LengthTargetSchema = z.enum(['2min', '5min', '10min']);
export type LengthTarget = z.infer<typeof LengthTargetSchema>;

export const LanguageCodeSchema = z.enum([
  'en', 'hi', 'bn', 'mr', 'ta', 'te', 'gu', 'kn', 'ml', 'pa', 'or', 'ur'
]);
export type LanguageCode = z.infer<typeof LanguageCodeSchema>;

export type LanguageCapability = 'voice_and_captions' | 'captions_only';

export interface LanguageInfo {
  code: LanguageCode;
  name: string;
  nativeName: string;
  dir: 'ltr' | 'rtl';
  capability: LanguageCapability;
  defaultVoice: string;
  piperVoice: string;
}

export const SUPPORTED_LANGUAGES: LanguageInfo[] = [
  { code: 'en', name: 'English', nativeName: 'English', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Studio Aria (en-IN)', piperVoice: 'piper-en_US-lessac-medium' },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Kavya (hi-IN)', piperVoice: 'piper-hi_IN-rohan-medium' },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Tanishaa (bn-IN)', piperVoice: 'piper-bn_IN-priya-medium' },
  { code: 'mr', name: 'Marathi', nativeName: 'मराठी', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Aarohi (mr-IN)', piperVoice: 'captions-fallback' },
  { code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Pallavi (ta-IN)', piperVoice: 'piper-ta_IN-valluvar-medium' },
  { code: 'te', name: 'Telugu', nativeName: 'తెలుగు', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Shruti (te-IN)', piperVoice: 'piper-te_IN-maya-medium' },
  { code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Dhwani (gu-IN)', piperVoice: 'captions-fallback' },
  { code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Sapna (kn-IN)', piperVoice: 'captions-fallback' },
  { code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', dir: 'ltr', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Sobhana (ml-IN)', piperVoice: 'piper-ml_IN-arjun-medium' },
  { code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', dir: 'ltr', capability: 'captions_only', defaultVoice: 'Captions only (No TTS voice)', piperVoice: 'captions-fallback' },
  { code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ', dir: 'ltr', capability: 'captions_only', defaultVoice: 'Captions only (No TTS voice)', piperVoice: 'captions-fallback' },
  { code: 'ur', name: 'Urdu', nativeName: 'اردو', dir: 'rtl', capability: 'voice_and_captions', defaultVoice: 'Cloud Neural Uzma (ur-IN)', piperVoice: 'piper-ur_PK-sadaf-medium' },
];

export const LLMProviderNameSchema = z.enum(['mock', 'gemini', 'anthropic', 'openai', 'ollama']);
export type LLMProviderName = z.infer<typeof LLMProviderNameSchema>;

export const TTSProviderNameSchema = z.enum(['mock', 'cloud', 'piper']);
export type TTSProviderName = z.infer<typeof TTSProviderNameSchema>;

export interface ParagraphSpan {
  id: string;
  sectionId: string;
  sectionTitle: string;
  page: number;
  text: string;
  citationKey: string; // e.g. doc:p1/sec-intro
}

export interface DocumentFigure {
  id: string;
  label: string;
  page: number;
  caption: string;
  imageUrl: string;
  citationKey: string; // e.g. doc:p3/fig-1
}

export interface DocumentTable {
  id: string;
  label: string;
  page: number;
  caption: string;
  columns: string[];
  units: Record<string, string>;
  rows: Array<Record<string, string | number>>;
  citationKey: string; // e.g. doc:p5/table-1
}

export interface DocumentEquation {
  id: string;
  label: string;
  page: number;
  latex: string;
  description: string;
  citationKey: string; // e.g. doc:p4/eq-1
}

export interface DocumentReference {
  id: string;
  title: string;
  authors: string;
  year: number;
  doi?: string;
  arxivId?: string;
  url: string;
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
  paragraphs: ParagraphSpan[];
  figures: DocumentFigure[];
  tables: DocumentTable[];
  equations: DocumentEquation[];
  references: DocumentReference[];
}

export const UnderstandOutputSchema = z.object({
  claims: z.array(z.object({
    id: z.string(),
    statement: z.string(),
    citationKey: z.string(),
  })),
  methodSteps: z.array(z.object({
    step: z.number(),
    title: z.string(),
    summary: z.string(),
    citationKey: z.string(),
  })),
  results: z.array(z.object({
    metric: z.string(),
    value: z.string(),
    citationKey: z.string(),
  })),
  limitations: z.array(z.object({
    statement: z.string(),
    citationKey: z.string(),
  })),
  glossary: z.array(z.object({
    term: z.string(),
    definition: z.string(),
    citationKey: z.string(),
  })),
  hardParts: z.array(z.object({
    id: z.string(),
    term: z.string(),
    reason: z.string(),
    targetDepth: DepthSchema,
  })),
});
export type UnderstandOutput = z.infer<typeof UnderstandOutputSchema>;

export type SourceTier = 1 | 2 | 3;

export interface ClarificationSource {
  id: string;
  hardPartId: string;
  term: string;
  tier: SourceTier;
  providerName: string;
  title: string;
  url: string;
  year: number;
  relevanceScore: number;
  quote: string; // Strictly <= 25 words
  confidenceLabel: 'high' | 'lower confidence';
  contradictsPaper: boolean;
  viewLabel?: 'Differing view';
}

export const DiagramVisualSpecSchema = z.object({
  kind: z.literal('diagram'),
  title: z.string(),
  nodes: z.array(z.object({
    id: z.string(),
    label: z.string(),
    group: z.string(),
    step: z.number(),
  })),
  edges: z.array(z.object({
    from: z.string(),
    to: z.string(),
    label: z.string().optional(),
    step: z.number(),
  })),
});

export const ChartVisualSpecSchema = z.object({
  kind: z.literal('chart'),
  title: z.string(),
  chartType: z.enum(['bar', 'grouped-bar', 'line']),
  tableId: z.string(),
  xColumn: z.string(),
  yColumns: z.array(z.string()),
  highlightRow: z.string().optional(),
  // Values are resolved strictly from DocumentTable at render time, never trusted from LLM
  resolvedSeries: z.array(z.object({
    label: z.string(),
    values: z.record(z.string(), z.union([z.number(), z.string()])),
  })).optional(),
});

export const FigureVisualSpecSchema = z.object({
  kind: z.literal('figure'),
  title: z.string(),
  figureId: z.string(),
  caption: z.string(),
  highlightBoxes: z.array(z.object({
    xPct: z.number(),
    yPct: z.number(),
    wPct: z.number(),
    hPct: z.number(),
    label: z.string(),
    step: z.number(),
  })),
});

export const EquationVisualSpecSchema = z.object({
  kind: z.literal('equation'),
  title: z.string(),
  equationId: z.string(),
  latex: z.string(),
  terms: z.array(z.object({
    symbolLatex: z.string(),
    meaning: z.string(),
    step: z.number(),
  })),
});

export const CardVisualSpecSchema = z.object({
  kind: z.enum(['title', 'takeaway']),
  title: z.string(),
  subtitle: z.string(),
  bullets: z.array(z.string()),
  isAnalogy: z.boolean().optional(),
});

export const VisualSpecSchema = z.discriminatedUnion('kind', [
  DiagramVisualSpecSchema,
  ChartVisualSpecSchema,
  FigureVisualSpecSchema,
  EquationVisualSpecSchema,
  CardVisualSpecSchema,
]);
export type VisualSpec = z.infer<typeof VisualSpecSchema>;

export const NarratedSentenceSchema = z.object({
  id: z.string(),
  text: z.string(),
  translatedText: z.string().optional(),
  citations: z.array(z.string()),
  isAnalogy: z.boolean().optional(),
});
export type NarratedSentence = z.infer<typeof NarratedSentenceSchema>;

export const StoryboardSceneSchema = z.object({
  id: z.string(),
  order: z.number(),
  arcPhase: z.enum(['why_it_matters', 'background', 'method', 'results', 'limitations', 'whats_next']),
  chapterTitle: z.string(),
  translatedChapterTitle: z.string().optional(),
  narration: z.string(),
  translatedNarration: z.string().optional(),
  sentences: z.array(NarratedSentenceSchema),
  visualSpec: VisualSpecSchema,
  citations: z.array(z.string()),
  durationSeconds: z.number().positive(),
  startSeconds: z.number().nonnegative(),
});
export type StoryboardScene = z.infer<typeof StoryboardSceneSchema>;

export type JobStageName =
  | 'ingest'
  | 'understand'
  | 'clarify'
  | 'plan'
  | 'translate'
  | 'render';

export type JobStatus =
  | 'queued'
  | 'ingesting'
  | 'understanding'
  | 'clarifying'
  | 'planning'
  | 'translating'
  | 'rendering'
  | 'ready'
  | 'failed';

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
  languageCapability: LanguageCapability;
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

export interface JobRecord {
  id: string;
  documentId: string;
  ownerId: string;
  status: JobStatus;
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
  understand?: UnderstandOutput;
  clarifications?: ClarificationSource[];
  scenes?: StoryboardScene[];
  videoId?: string;
  createdAt: string;
  updatedAt: string;
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

export interface ShareLinkRecord {
  token: string;
  documentId: string;
  videoId: string;
  createdBy: string;
  role: 'viewer';
  expiresAt: string;
  createdAt: string;
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

export interface QASentence {
  text: string;
  citations: string[];
  jumpToSceneId?: string;
  jumpToSeconds?: number;
}

export interface QAResponse {
  question: string;
  answered: boolean;
  refusalText?: string;
  sentences: QASentence[];
  retrievedChunks: Array<{
    id: string;
    sourceType: 'document' | 'clarification';
    citationKey: string;
    title: string;
    snippet: string;
    rrfScore: number;
    tier?: SourceTier;
    confidenceLabel?: 'high' | 'lower confidence';
    viewLabel?: 'Differing view';
    url?: string;
  }>;
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

export const ResearchNoteSchema = z.object({
  id: z.string(),
  documentId: z.string(),
  citationKey: z.string(),
  page: z.number().int().positive(),
  title: z.string(),
  body: z.string(),
  colorTag: z.enum(['amber', 'blue', 'emerald', 'slate']),
  createdAt: z.string(),
  updatedAt: z.string(),
});
export type ResearchNote = z.infer<typeof ResearchNoteSchema>;

export const SketchStrokeSchema = z.object({
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/),
  width: z.number().min(1).max(20),
  points: z.array(z.object({ x: z.number(), y: z.number() })).min(1),
});
export type SketchStroke = z.infer<typeof SketchStrokeSchema>;

export const ResearchSketchSchema = z.object({
  id: z.string(),
  documentId: z.string(),
  citationKey: z.string(),
  page: z.number().int().positive(),
  title: z.string(),
  width: z.number().positive(),
  height: z.number().positive(),
  strokes: z.array(SketchStrokeSchema).min(1),
  createdAt: z.string(),
});
export type ResearchSketch = z.infer<typeof ResearchSketchSchema>;

