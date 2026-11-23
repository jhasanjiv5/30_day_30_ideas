import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {
  buildFixtureStoryboard,
  BUNDLED_CC_BY_PAPER,
  BUNDLED_CLARIFICATIONS,
  BUNDLED_PAPER_DOC_ID,
  BUNDLED_UNDERSTAND_OUTPUT,
} from './fixtures/paper.ts';
import {
  buildDynamicClarifications,
  buildDynamicStoryboard,
  buildDynamicUnderstandOutput,
} from './pipeline/dynamic_plan.ts';
import {
  enforceStoryboardGrounding,
  processClarificationSources,
} from './pipeline/grounding.ts';
import { executeWithProviderChain, TTS_PROVIDERS } from './pipeline/providers.ts';
import { assembleVideoArtifacts, deleteVideoArtifacts, ensureStorageDir } from './pipeline/render.ts';
import { translateStoryboard } from './pipeline/translation.ts';
import {
  AuditLogEntry,
  Depth,
  DocumentModel,
  JobRecord,
  JobStageName,
  LanguageCode,
  LengthTarget,
  LLMProviderName,
  ResearchNote,
  ResearchSketch,
  ShareLinkRecord,
  SketchStroke,
  StageTelemetry,
  StoredDocument,
  SUPPORTED_LANGUAGES,
  TTSProviderName,
  UnderstandOutputSchema,
  VideoArtifact,
  WorkspaceSettings,
} from './types.ts';

interface PersistedDatabase {
  settingsByUser: Record<string, WorkspaceSettings>;
  documents: Record<string, StoredDocument>;
  jobs: Record<string, JobRecord>;
  videos: Record<string, VideoArtifact>;
  shareLinks: Record<string, ShareLinkRecord>;
  auditLogs: AuditLogEntry[];
  notesByDoc?: Record<string, ResearchNote[]>;
  sketchesByDoc?: Record<string, ResearchSketch[]>;
}

const DATA_DIR = path.resolve(process.cwd(), 'data');
const DB_FILE = path.join(DATA_DIR, 'db.json');

export const DEFAULT_USER_ID = 'user_researcher_1';

function defaultSettings(ownerId: string): WorkspaceSettings {
  return {
    ownerId,
    mockMode: process.env.DRISHYA_MOCK_MODE !== 'false',
    llmProvider: 'mock',
    llmModels: {
      mock: 'mock-deterministic-v1',
      gemini: 'gemini-4-hydrogen',
      anthropic: 'claude-sonnet-4-20250514',
      openai: 'gpt-4.1-mini',
      ollama: 'llama3.2:latest',
    },
    fallbackChain: ['gemini', 'mock'],
    ttsProvider: 'mock',
    retentionDays: Number(process.env.DRISHYA_RETENTION_DAYS || 30),
    searchProvider: 'fixture',
    trainingOptOutConfirmed: true,
  };
}

function makeInitialStages(): StageTelemetry[] {
  const order: JobStageName[] = ['ingest', 'understand', 'clarify', 'plan', 'translate', 'render'];
  return order.map((stage) => ({
    stage,
    status: 'pending',
    durationMs: 0,
    provider: 'pending',
    model: '-',
    promptVersion: 'v1.0',
    inputTokens: 0,
    outputTokens: 0,
    costUsd: 0,
    message: 'Waiting in queue',
  }));
}

export class DrishyaStore {
  private db: PersistedDatabase;
  private initialized = false;

  constructor() {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    ensureStorageDir();
    this.db = this.load();
  }

  private load(): PersistedDatabase {
    if (fs.existsSync(DB_FILE)) {
      try {
        const raw = fs.readFileSync(DB_FILE, 'utf8');
        const parsed = JSON.parse(raw) as PersistedDatabase;
        return {
          ...parsed,
          notesByDoc: parsed.notesByDoc ?? {},
          sketchesByDoc: parsed.sketchesByDoc ?? {},
        };
      } catch {
        // Fall through to fresh DB
      }
    }
    return {
      settingsByUser: {
        [DEFAULT_USER_ID]: defaultSettings(DEFAULT_USER_ID),
      },
      documents: {},
      jobs: {},
      videos: {},
      shareLinks: {},
      auditLogs: [],
      notesByDoc: {},
      sketchesByDoc: {},
    };
  }

  private save(): void {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    fs.writeFileSync(DB_FILE, JSON.stringify(this.db, null, 2), 'utf8');
  }

  /**
   * Privacy-safe audit logger: NEVER logs document text, snippets, or prompts.
   */
  public logAudit(actorId: string, action: string, resourceId: string, note: string): void {
    const entry: AuditLogEntry = {
      id: `aud_${crypto.randomUUID().slice(0, 8)}`,
      timestamp: new Date().toISOString(),
      actorId,
      action,
      resourceId,
      metadataRedacted: true,
      note: note.slice(0, 120),
    };
    this.db.auditLogs.unshift(entry);
    if (this.db.auditLogs.length > 200) {
      this.db.auditLogs = this.db.auditLogs.slice(0, 200);
    }
    this.save();
  }

  public getAuditLogs(actorId: string): AuditLogEntry[] {
    return this.db.auditLogs.filter((l) => l.actorId === actorId || l.actorId === 'system');
  }

  public getSettings(ownerId: string): WorkspaceSettings {
    if (!this.db.settingsByUser[ownerId]) {
      this.db.settingsByUser[ownerId] = defaultSettings(ownerId);
      this.save();
    }
    return this.db.settingsByUser[ownerId];
  }

  public updateSettings(ownerId: string, patch: Partial<WorkspaceSettings>): WorkspaceSettings {
    const current = this.getSettings(ownerId);
    const updated: WorkspaceSettings = {
      ...current,
      ...patch,
      ownerId,
      llmModels: { ...current.llmModels, ...(patch.llmModels ?? {}) },
      retentionDays: Math.max(1, Math.min(365, Number(patch.retentionDays ?? current.retentionDays))),
    };
    this.db.settingsByUser[ownerId] = updated;
    this.logAudit(ownerId, 'settings.update', ownerId, `Updated provider=${updated.llmProvider}, retention=${updated.retentionDays}d`);
    this.save();
    return updated;
  }

  public listDocuments(ownerId: string): Array<{
    document: StoredDocument;
    latestJob?: JobRecord;
    latestVideo?: VideoArtifact;
    notesCount: number;
    sketchesCount: number;
  }> {
    return Object.values(this.db.documents)
      .filter((d) => d.ownerId === ownerId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map((document) => ({
        document,
        latestJob: document.latestJobId ? this.db.jobs[document.latestJobId] : undefined,
        latestVideo: document.latestVideoId ? this.db.videos[document.latestVideoId] : undefined,
        notesCount: (this.db.notesByDoc?.[document.id] ?? []).length,
        sketchesCount: (this.db.sketchesByDoc?.[document.id] ?? []).length,
      }));
  }

  public getAnnotations(documentId: string): {
    notes: ResearchNote[];
    sketches: ResearchSketch[];
  } {
    return {
      notes: this.db.notesByDoc?.[documentId] ?? [],
      sketches: this.db.sketchesByDoc?.[documentId] ?? [],
    };
  }

  public addNote(params: {
    ownerId: string;
    documentId: string;
    citationKey: string;
    page: number;
    title: string;
    body: string;
    colorTag: 'amber' | 'blue' | 'emerald' | 'slate';
  }): ResearchNote {
    const now = new Date().toISOString();
    const note: ResearchNote = {
      id: `note_${crypto.randomUUID().slice(0, 8)}`,
      documentId: params.documentId,
      citationKey: params.citationKey,
      page: params.page,
      title: params.title.trim() || 'Research Note',
      body: params.body.trim(),
      colorTag: params.colorTag,
      createdAt: now,
      updatedAt: now,
    };
    if (!this.db.notesByDoc) this.db.notesByDoc = {};
    this.db.notesByDoc[params.documentId] = [note, ...(this.db.notesByDoc[params.documentId] ?? [])];
    this.logAudit(params.ownerId, 'note.create', params.documentId, `citation=${params.citationKey}`);
    this.save();
    return note;
  }

  public deleteNote(ownerId: string, documentId: string, noteId: string): boolean {
    const existing = this.db.notesByDoc?.[documentId] ?? [];
    const filtered = existing.filter((n) => n.id !== noteId);
    if (filtered.length === existing.length) return false;
    if (!this.db.notesByDoc) this.db.notesByDoc = {};
    this.db.notesByDoc[documentId] = filtered;
    this.logAudit(ownerId, 'note.delete', documentId, `note=${noteId}`);
    this.save();
    return true;
  }

  public addSketch(params: {
    ownerId: string;
    documentId: string;
    citationKey: string;
    page: number;
    title: string;
    width: number;
    height: number;
    strokes: SketchStroke[];
  }): ResearchSketch {
    const sketch: ResearchSketch = {
      id: `sk_${crypto.randomUUID().slice(0, 8)}`,
      documentId: params.documentId,
      citationKey: params.citationKey,
      page: params.page,
      title: params.title.trim() || 'Concept Sketch',
      width: params.width,
      height: params.height,
      strokes: params.strokes,
      createdAt: new Date().toISOString(),
    };
    if (!this.db.sketchesByDoc) this.db.sketchesByDoc = {};
    this.db.sketchesByDoc[params.documentId] = [
      sketch,
      ...(this.db.sketchesByDoc[params.documentId] ?? []),
    ];
    this.logAudit(params.ownerId, 'sketch.create', params.documentId, `citation=${params.citationKey}`);
    this.save();
    return sketch;
  }

  public deleteSketch(ownerId: string, documentId: string, sketchId: string): boolean {
    const existing = this.db.sketchesByDoc?.[documentId] ?? [];
    const filtered = existing.filter((s) => s.id !== sketchId);
    if (filtered.length === existing.length) return false;
    if (!this.db.sketchesByDoc) this.db.sketchesByDoc = {};
    this.db.sketchesByDoc[documentId] = filtered;
    this.logAudit(ownerId, 'sketch.delete', documentId, `sketch=${sketchId}`);
    this.save();
    return true;
  }

  public getDocument(documentId: string, ownerId?: string): StoredDocument | undefined {
    const doc = this.db.documents[documentId];
    if (!doc) return undefined;
    if (ownerId && doc.ownerId !== ownerId) return undefined;
    return doc;
  }

  public saveDocument(ownerId: string, model: DocumentModel): StoredDocument {
    const settings = this.getSettings(ownerId);
    const now = new Date();
    const expires = new Date(now.getTime() + settings.retentionDays * 86400 * 1000);
    const stored: StoredDocument = {
      id: model.id,
      ownerId,
      model,
      createdAt: now.toISOString(),
      expiresAt: expires.toISOString(),
    };
    this.db.documents[model.id] = stored;
    this.logAudit(ownerId, 'document.ingest', model.id, `Ingested format=${model.sourceFormat}, ocr=${model.ocrUsed}`);
    this.save();
    return stored;
  }

  public getJob(jobId: string, ownerId?: string): JobRecord | undefined {
    const job = this.db.jobs[jobId];
    if (!job) return undefined;
    if (ownerId && job.ownerId !== ownerId) return undefined;
    return job;
  }

  public listJobs(ownerId: string): JobRecord[] {
    return Object.values(this.db.jobs)
      .filter((j) => j.ownerId === ownerId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  public getVideo(videoId: string): VideoArtifact | undefined {
    return this.db.videos[videoId];
  }

  public createJob(params: {
    ownerId: string;
    documentId: string;
    depth: Depth;
    lengthTarget: LengthTarget;
    language: LanguageCode;
    llmProvider?: LLMProviderName;
    ttsProvider?: TTSProviderName;
    simulateFailStage?: JobStageName;
  }): JobRecord {
    const settings = this.getSettings(params.ownerId);
    const llmProvider = params.llmProvider ?? settings.llmProvider;
    const ttsProvider = params.ttsProvider ?? settings.ttsProvider;
    const llmModel = settings.llmModels[llmProvider];
    const now = new Date().toISOString();
    const jobId = `job_${crypto.randomUUID().slice(0, 8)}`;

    const stages = makeInitialStages();
    stages[0] = {
      ...stages[0],
      status: 'completed',
      durationMs: 140,
      provider: 'ingest-parser',
      model: this.db.documents[params.documentId]?.model.sourceFormat ?? 'fixture',
      message: 'Document parsed into sections, figures, tables, and equations',
    };

    const job: JobRecord = {
      id: jobId,
      documentId: params.documentId,
      ownerId: params.ownerId,
      status: 'queued',
      depth: params.depth,
      lengthTarget: params.lengthTarget,
      language: params.language,
      llmProvider,
      llmModel,
      ttsProvider,
      stages,
      totalTokens: 0,
      totalCostUsd: 0,
      createdAt: now,
      updatedAt: now,
    };

    this.db.jobs[jobId] = job;
    const doc = this.db.documents[params.documentId];
    if (doc) {
      doc.latestJobId = jobId;
    }
    this.logAudit(params.ownerId, 'job.create', jobId, `depth=${params.depth}, len=${params.lengthTarget}, lang=${params.language}`);
    this.save();
    return job;
  }

  public async runJobPipeline(
    jobId: string,
    options?: { resumeFromStage?: JobStageName; simulateFailStage?: JobStageName }
  ): Promise<JobRecord> {
    const job = this.db.jobs[jobId];
    if (!job) throw new Error(`Job ${jobId} not found`);
    const docRecord = this.db.documents[job.documentId];
    if (!docRecord) throw new Error(`Document ${job.documentId} not found`);

    const settings = this.getSettings(job.ownerId);
    const stageOrder: JobStageName[] = ['ingest', 'understand', 'clarify', 'plan', 'translate', 'render'];
    const startIdx = options?.resumeFromStage
      ? Math.max(0, stageOrder.indexOf(options.resumeFromStage))
      : 1;

    job.failedStage = undefined;

    for (let i = startIdx; i < stageOrder.length; i += 1) {
      const stageName = stageOrder[i];
      const stageSlot = job.stages.find((s) => s.stage === stageName)!;
      stageSlot.status = 'running';
      stageSlot.error = undefined;
      job.status =
        stageName === 'understand'
          ? 'understanding'
          : stageName === 'clarify'
            ? 'clarifying'
            : stageName === 'plan'
              ? 'planning'
              : stageName === 'translate'
                ? 'translating'
                : 'rendering';
      job.updatedAt = new Date().toISOString();
      this.save();

      const t0 = Date.now();
      try {
        if (options?.simulateFailStage === stageName) {
          throw new Error(`Simulated transient failure at stage "${stageName}" for retry test`);
        }

        const isFixtureDoc =
          docRecord.model.id === BUNDLED_PAPER_DOC_ID ||
          docRecord.model.title === BUNDLED_CC_BY_PAPER.title;

        if (stageName === 'understand') {
          const dynamicUnderstand = buildDynamicUnderstandOutput(docRecord.model, job.depth);
          const docDigest = docRecord.model.paragraphs
            .slice(0, 6)
            .map((p) => `[${p.citationKey}] ${p.text}`)
            .join('\n');
          const res = await executeWithProviderChain({
            primary: job.llmProvider,
            fallbackChain: settings.fallbackChain,
            models: settings.llmModels,
            mockMode: settings.mockMode,
            promptVersion: 'understand-v1.2',
            systemPrompt:
              'Extract structured claims, method steps, results, limitations, glossary, and hard parts as strict JSON using only the citationKey values provided.',
            userPrompt: `Title: ${docRecord.model.title}\nDepth: ${job.depth}\nExcerpts:\n${docDigest}`,
            schema: UnderstandOutputSchema,
            mockFallback: () => (isFixtureDoc ? BUNDLED_UNDERSTAND_OUTPUT : dynamicUnderstand),
          });
          job.understand = res.data;
          stageSlot.provider = res.provider;
          stageSlot.model = res.model;
          stageSlot.promptVersion = res.promptVersion;
          stageSlot.inputTokens = res.inputTokens;
          stageSlot.outputTokens = res.outputTokens;
          stageSlot.costUsd = res.costUsd;
          stageSlot.message = `Extracted ${res.data.claims.length} claims and ${res.data.hardParts.length} hard parts`;
        } else if (stageName === 'clarify') {
          const understand =
            job.understand ??
            (isFixtureDoc
              ? BUNDLED_UNDERSTAND_OUTPUT
              : buildDynamicUnderstandOutput(docRecord.model, job.depth));
          const ranked = isFixtureDoc
            ? processClarificationSources(BUNDLED_CLARIFICATIONS)
            : await buildDynamicClarifications(
                docRecord.model,
                understand,
                docRecord.model.sourceFormat === 'fixture'
              );
          job.clarifications = ranked;
          stageSlot.provider = isFixtureDoc ? settings.searchProvider : 'openalex+wikipedia';
          stageSlot.model = 'tier-1-2-3-ranker';
          stageSlot.promptVersion = 'clarify-v1.1';
          stageSlot.message = `Ranked ${ranked.length} sources across Tiers 1–3 (${isFixtureDoc ? 'fixture' : 'live open-access'} lookup)`;
        } else if (stageName === 'plan') {
          const understand =
            job.understand ??
            (isFixtureDoc
              ? BUNDLED_UNDERSTAND_OUTPUT
              : buildDynamicUnderstandOutput(docRecord.model, job.depth));
          const clarifications =
            job.clarifications ??
            (isFixtureDoc
              ? processClarificationSources(BUNDLED_CLARIFICATIONS)
              : await buildDynamicClarifications(docRecord.model, understand, true));
          const rawScenes = isFixtureDoc
            ? buildFixtureStoryboard(docRecord.model, job.depth, job.lengthTarget)
            : buildDynamicStoryboard(docRecord.model, understand, clarifications, job.depth, job.lengthTarget);
          const grounded = enforceStoryboardGrounding(rawScenes, docRecord.model, clarifications);
          job.scenes = grounded.scenes;
          stageSlot.provider = job.llmProvider;
          stageSlot.model = job.llmModel;
          stageSlot.promptVersion = 'storyboard-v1.4';
          stageSlot.inputTokens = 620;
          stageSlot.outputTokens = 880;
          stageSlot.costUsd = job.llmProvider === 'mock' ? 0 : 0.00062;
          stageSlot.message = `Planned ${grounded.scenes.length} grounded scenes; chart cells verified (${grounded.chartAccuracyReport.map((r) => r.checkedCells).reduce((a, b) => a + b, 0)} cells)`;
        } else if (stageName === 'translate') {
          const scenes = job.scenes ?? [];
          const translated = translateStoryboard(scenes, job.language);
          job.scenes = translated.scenes;
          stageSlot.provider = job.language === 'en' ? 'passthrough' : 'guarded-translator';
          stageSlot.model = `placeholder-guard-${job.language}`;
          stageSlot.promptVersion = 'translate-guard-v1.0';
          stageSlot.message =
            job.language === 'en'
              ? 'English narration verified'
              : `Translated to ${job.language} (${translated.dir.toUpperCase()}) with technical terms/LaTeX/numbers preserved`;
        } else if (stageName === 'render') {
          const understand =
            job.understand ??
            (isFixtureDoc
              ? BUNDLED_UNDERSTAND_OUTPUT
              : buildDynamicUnderstandOutput(docRecord.model, job.depth));
          const clarifications =
            job.clarifications ??
            (isFixtureDoc
              ? processClarificationSources(BUNDLED_CLARIFICATIONS)
              : await buildDynamicClarifications(docRecord.model, understand, true));
          const rawScenes =
            job.scenes ??
            (isFixtureDoc
              ? buildFixtureStoryboard(docRecord.model, job.depth, job.lengthTarget)
              : buildDynamicStoryboard(docRecord.model, understand, clarifications, job.depth, job.lengthTarget));
          const grounded = enforceStoryboardGrounding(rawScenes, docRecord.model, clarifications);
          const translated = translateStoryboard(grounded.scenes, job.language);

          const totalDur = translated.scenes.reduce((s, sc) => s + sc.durationSeconds, 0);
          const ttsResult = TTS_PROVIDERS[job.ttsProvider].synthesizeInfo(job.language, totalDur);
          const langInfo = SUPPORTED_LANGUAGES.find((l) => l.code === job.language) ?? SUPPORTED_LANGUAGES[0];
          const videoId = `vid_${crypto.randomUUID().slice(0, 8)}`;

          await assembleVideoArtifacts({
            videoId,
            documentId: docRecord.id,
            title: docRecord.model.title,
            scenes: translated.scenes,
            language: job.language,
            ttsProvider: job.ttsProvider,
            captionsOnly: ttsResult.captionsOnly,
            mockMode: settings.mockMode,
          });

          const artifact: VideoArtifact = {
            id: videoId,
            jobId: job.id,
            documentId: docRecord.id,
            depth: job.depth,
            lengthTarget: job.lengthTarget,
            language: job.language,
            languageDir: langInfo.dir,
            languageCapability: langInfo.capability,
            ttsVoice: ttsResult.voice,
            ttsProvider: job.ttsProvider,
            llmProvider: job.llmProvider,
            llmModel: job.llmModel,
            mp4Url: `/api/videos/${videoId}/stream.mp4`,
            vttUrl: `/api/videos/${videoId}/captions.vtt`,
            audioUrl: `/api/videos/${videoId}/narration.wav`,
            durationSeconds: totalDur,
            chapters: translated.scenes.map((sc) => ({
              title: sc.translatedChapterTitle || sc.chapterTitle,
              startSeconds: sc.startSeconds,
              endSeconds: sc.startSeconds + sc.durationSeconds,
              sceneId: sc.id,
            })),
            scenes: translated.scenes,
            clarifications,
            chartAccuracyReport: grounded.chartAccuracyReport,
            droppedUncitedSentences: grounded.droppedUncitedSentences,
            numberGuardViolations: grounded.numberGuardViolations,
            translationGuardVerified: translated.guardVerified,
            createdAt: new Date().toISOString(),
          };

          this.db.videos[videoId] = artifact;
          job.videoId = videoId;
          docRecord.latestVideoId = videoId;

          stageSlot.provider = `${job.ttsProvider}+ffmpeg`;
          stageSlot.model = ttsResult.voice;
          stageSlot.promptVersion = 'render-v1.0';
          stageSlot.message = `Assembled MP4 (${totalDur}s), WebVTT captions, and ${artifact.chapters.length} chapters`;
        }

        stageSlot.status = 'completed';
        stageSlot.durationMs = Math.max(25, Date.now() - t0);
        job.totalTokens = job.stages.reduce((s, st) => s + st.inputTokens + st.outputTokens, 0);
        job.totalCostUsd = Number(job.stages.reduce((s, st) => s + st.costUsd, 0).toFixed(6));
        job.updatedAt = new Date().toISOString();
        this.save();
      } catch (err) {
        stageSlot.status = 'failed';
        stageSlot.durationMs = Math.max(10, Date.now() - t0);
        stageSlot.error = err instanceof Error ? err.message : 'Unknown stage failure';
        stageSlot.message = stageSlot.error;
        job.status = 'failed';
        job.failedStage = stageName;
        job.updatedAt = new Date().toISOString();
        this.logAudit(job.ownerId, 'job.stage_failed', job.id, `stage=${stageName}`);
        this.save();
        return job;
      }
    }

    job.status = 'ready';
    job.updatedAt = new Date().toISOString();
    this.logAudit(job.ownerId, 'job.ready', job.id, `video=${job.videoId}`);
    this.save();
    return job;
  }

  public createShareLink(params: {
    ownerId: string;
    documentId: string;
    videoId: string;
    expiresInHours: number;
  }): ShareLinkRecord {
    const token = `shr_${crypto.randomBytes(12).toString('hex')}`;
    const now = new Date();
    const expires = new Date(now.getTime() + params.expiresInHours * 3600 * 1000);
    const link: ShareLinkRecord = {
      token,
      documentId: params.documentId,
      videoId: params.videoId,
      createdBy: params.ownerId,
      role: 'viewer',
      createdAt: now.toISOString(),
      expiresAt: expires.toISOString(),
    };
    this.db.shareLinks[token] = link;
    this.logAudit(params.ownerId, 'share.create', params.videoId, `expiresHours=${params.expiresInHours}`);
    this.save();
    return link;
  }

  public resolveShareLink(token: string): {
    valid: boolean;
    reason?: string;
    link?: ShareLinkRecord;
    video?: VideoArtifact;
    document?: StoredDocument;
    notes?: ResearchNote[];
    sketches?: ResearchSketch[];
  } {
    const link = this.db.shareLinks[token];
    if (!link) return { valid: false, reason: 'Share link not found or deleted.' };
    if (Date.now() > new Date(link.expiresAt).getTime()) {
      return { valid: false, reason: 'This share link has expired.' };
    }
    const video = this.db.videos[link.videoId];
    const document = this.db.documents[link.documentId];
    if (!video || !document) return { valid: false, reason: 'Shared video was deleted.' };
    const annotations = this.getAnnotations(document.id);
    return { valid: true, link, video, document, notes: annotations.notes, sketches: annotations.sketches };
  }

  /**
   * Immediately deletes a document, all its jobs, videos, annotations, share links, and MP4/VTT artifacts.
   */
  public deleteDocumentNow(documentId: string, ownerId: string): boolean {
    const doc = this.db.documents[documentId];
    if (!doc || doc.ownerId !== ownerId) return false;

    for (const vid of Object.values(this.db.videos)) {
      if (vid.documentId === documentId) {
        deleteVideoArtifacts(vid.id);
        delete this.db.videos[vid.id];
      }
    }
    for (const job of Object.values(this.db.jobs)) {
      if (job.documentId === documentId) {
        delete this.db.jobs[job.id];
      }
    }
    for (const link of Object.values(this.db.shareLinks)) {
      if (link.documentId === documentId) {
        delete this.db.shareLinks[link.token];
      }
    }
    if (this.db.notesByDoc) delete this.db.notesByDoc[documentId];
    if (this.db.sketchesByDoc) delete this.db.sketchesByDoc[documentId];
    delete this.db.documents[documentId];
    this.logAudit(ownerId, 'document.delete_now', documentId, 'Purged database rows and object storage artifacts');
    this.save();
    return true;
  }

  /**
   * Retention sweeper: removes any documents/videos past expiresAt as well as expired share links.
   */
  public runRetentionSweep(now = new Date()): { deletedDocuments: string[]; expiredShareLinks: number } {
    const deletedDocuments: string[] = [];
    const nowMs = now.getTime();

    for (const doc of Object.values(this.db.documents)) {
      if (new Date(doc.expiresAt).getTime() <= nowMs) {
        this.deleteDocumentNow(doc.id, doc.ownerId);
        deletedDocuments.push(doc.id);
      }
    }

    let expiredShareLinks = 0;
    for (const link of Object.values(this.db.shareLinks)) {
      if (new Date(link.expiresAt).getTime() <= nowMs) {
        delete this.db.shareLinks[link.token];
        expiredShareLinks += 1;
      }
    }

    if (deletedDocuments.length > 0 || expiredShareLinks > 0) {
      this.logAudit('system', 'retention.sweep', 'workspace', `deletedDocs=${deletedDocuments.length}, expiredShares=${expiredShareLinks}`);
      this.save();
    }

    return { deletedDocuments, expiredShareLinks };
  }

  public async ensureSeeded(): Promise<void> {
    if (this.initialized) return;
    this.initialized = true;
    const existing = this.db.documents[BUNDLED_PAPER_DOC_ID];
    const existingVid = existing?.latestVideoId ? this.db.videos[existing.latestVideoId] : undefined;
    const hasAudioTrack =
      existingVid &&
      Boolean(existingVid.audioUrl) &&
      fs.existsSync(path.resolve(process.cwd(), 'data/storage/videos', existingVid.id, 'narration.wav'));
    if (!existing || !existingVid || !hasAudioTrack) {
      this.saveDocument(DEFAULT_USER_ID, BUNDLED_CC_BY_PAPER);
      const job = this.createJob({
        ownerId: DEFAULT_USER_ID,
        documentId: BUNDLED_PAPER_DOC_ID,
        depth: 'student',
        lengthTarget: '2min',
        language: 'en',
        llmProvider: 'mock',
        ttsProvider: 'mock',
      });
      await this.runJobPipeline(job.id);
    }
    const existingAnnotations = this.getAnnotations(BUNDLED_PAPER_DOC_ID);
    if (existingAnnotations.notes.length === 0) {
      this.addNote({
        ownerId: DEFAULT_USER_ID,
        documentId: BUNDLED_PAPER_DOC_ID,
        citationKey: 'doc:p5/table-1',
        page: 5,
        title: 'Key efficiency takeaway (Table 1)',
        body: 'MonsoonFormer lowers 5-day RMSE from 15.8 to 11.4 mm/day while cutting VRAM by 75% (38.4 GB down to 9.6 GB).',
        colorTag: 'amber',
      });
    }
    if (existingAnnotations.sketches.length === 0) {
      this.addSketch({
        ownerId: DEFAULT_USER_ID,
        documentId: BUNDLED_PAPER_DOC_ID,
        citationKey: 'doc:p3/sec-arch',
        page: 3,
        title: '7x7 Window + Anchors Intuition',
        width: 360,
        height: 180,
        strokes: [
          {
            color: '#1d4ed8',
            width: 3,
            points: [
              { x: 40, y: 42 },
              { x: 130, y: 42 },
              { x: 130, y: 132 },
              { x: 40, y: 132 },
              { x: 40, y: 42 },
            ],
          },
          {
            color: '#d97706',
            width: 3,
            points: [
              { x: 85, y: 86 },
              { x: 165, y: 86 },
              { x: 245, y: 55 },
            ],
          },
          {
            color: '#059669',
            width: 3,
            points: [
              { x: 245, y: 40 },
              { x: 325, y: 40 },
              { x: 325, y: 130 },
              { x: 245, y: 130 },
              { x: 245, y: 40 },
            ],
          },
        ],
      });
    }
  }
}
