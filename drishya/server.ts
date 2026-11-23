import crypto from 'node:crypto';
import express from 'express';
import fs from 'node:fs';
import multer from 'multer';
import path from 'node:path';
import { createServer as createViteServer } from 'vite';
import { BUNDLED_CC_BY_PAPER } from './server/fixtures/paper.ts';
import {
  buildJsonResearchArchive,
  buildMarkdownNotebook,
  buildPortableHtmlNotebook,
} from './server/pipeline/export.ts';
import { ingestFromRemoteUrl, parseUploadedDocumentBuffer } from './server/pipeline/ingest.ts';
import { answerGroundedQuestion } from './server/pipeline/qa.ts';
import { STORAGE_ROOT } from './server/pipeline/render.ts';
import { DEFAULT_USER_ID, DrishyaStore } from './server/store.ts';
import {
  DepthSchema,
  JobStageName,
  LanguageCodeSchema,
  LengthTargetSchema,
  LLMProviderNameSchema,
  SketchStrokeSchema,
  SUPPORTED_LANGUAGES,
  TTSProviderNameSchema,
} from './server/types.ts';

const PORT = Number(process.env.PORT || 3000);
const SESSION_SECRET = process.env.DRISHYA_SESSION_SECRET || crypto.randomBytes(32).toString('hex');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 },
});

interface SessionRecord {
  userId: string;
  email: string;
  name: string;
  authMethod: 'magic-link' | 'google' | 'workspace';
  createdAt: number;
}

const activeSessions = new Map<string, SessionRecord>();
const pendingMagicLinks = new Map<string, { email: string; expiresAt: number }>();

function signToken(payload: string): string {
  return crypto.createHmac('sha256', SESSION_SECRET).update(payload).digest('hex');
}

function resolveUser(req: express.Request): { userId: string; email: string; name: string; authMethod: string } {
  const auth = req.headers.authorization;
  if (auth && auth.startsWith('Bearer ')) {
    const token = auth.slice(7).trim();
    const session = activeSessions.get(token);
    if (session) return session;
  }
  return {
    userId: DEFAULT_USER_ID,
    email: 'researcher@drishya.local',
    name: 'Workspace Owner',
    authMethod: 'workspace',
  };
}

export async function createAppServer() {
  const app = express();
  const store = new DrishyaStore();
  void store.ensureSeeded();

  // Periodic privacy retention sweep every hour
  const sweepTimer = setInterval(() => {
    store.runRetentionSweep();
  }, 60 * 60 * 1000);
  sweepTimer.unref();

  app.use(express.json({ limit: '2mb' }));

  // Auth: Email magic link & Google sign-in flow
  app.get('/api/auth/me', (req, res) => {
    res.json(resolveUser(req));
  });

  app.post('/api/auth/magic-link', (req, res) => {
    const email = String(req.body?.email ?? '').trim().toLowerCase();
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid email address required.' });
    }
    const magicToken = crypto.randomBytes(16).toString('hex');
    pendingMagicLinks.set(magicToken, { email, expiresAt: Date.now() + 15 * 60 * 1000 });
    return res.json({
      sent: true,
      magicToken, // Returned for instant preview verification without external SMTP
      message: 'Magic sign-in link issued (15-minute expiry).',
    });
  });

  app.post('/api/auth/verify-magic-link', (req, res) => {
    const magicToken = String(req.body?.magicToken ?? '').trim();
    const entry = pendingMagicLinks.get(magicToken);
    if (!entry || Date.now() > entry.expiresAt) {
      return res.status(401).json({ error: 'Invalid or expired magic link.' });
    }
    pendingMagicLinks.delete(magicToken);
    const sessionToken = `${crypto.randomUUID()}.${signToken(entry.email).slice(0, 16)}`;
    const session: SessionRecord = {
      userId: DEFAULT_USER_ID,
      email: entry.email,
      name: entry.email.split('@')[0],
      authMethod: 'magic-link',
      createdAt: Date.now(),
    };
    activeSessions.set(sessionToken, session);
    return res.json({ token: sessionToken, user: session });
  });

  app.post('/api/auth/google', (req, res) => {
    const email = String(req.body?.email ?? 'scholar@gmail.com').trim().toLowerCase();
    const name = String(req.body?.name ?? 'Google Scholar User').trim();
    const sessionToken = `${crypto.randomUUID()}.${signToken(email).slice(0, 16)}`;
    const session: SessionRecord = {
      userId: DEFAULT_USER_ID,
      email,
      name,
      authMethod: 'google',
      createdAt: Date.now(),
    };
    activeSessions.set(sessionToken, session);
    return res.json({ token: sessionToken, user: session });
  });

  // Languages & capabilities
  app.get('/api/languages', (_req, res) => {
    res.json({ languages: SUPPORTED_LANGUAGES });
  });

  // Settings & privacy audit logs
  app.get('/api/settings', (req, res) => {
    const user = resolveUser(req);
    res.json({
      settings: store.getSettings(user.userId),
      auditLogs: store.getAuditLogs(user.userId),
    });
  });

  app.put('/api/settings', (req, res) => {
    const user = resolveUser(req);
    try {
      const body = req.body ?? {};
      if (body.llmProvider) LLMProviderNameSchema.parse(body.llmProvider);
      if (body.ttsProvider) TTSProviderNameSchema.parse(body.ttsProvider);
      const updated = store.updateSettings(user.userId, body);
      return res.json({ settings: updated, auditLogs: store.getAuditLogs(user.userId) });
    } catch (err) {
      return res.status(400).json({ error: err instanceof Error ? err.message : 'Invalid settings' });
    }
  });

  app.post('/api/retention/sweep', (req, res) => {
    const user = resolveUser(req);
    const result = store.runRetentionSweep();
    res.json({ ...result, auditLogs: store.getAuditLogs(user.userId) });
  });

  // Library: list documents + latest job + latest video
  app.get('/api/documents', (req, res) => {
    const user = resolveUser(req);
    res.json({ items: store.listDocuments(user.userId) });
  });

  // Ingest via URL, bundled CC-BY fixture, or uploaded PDF/DOCX/HTML
  app.post('/api/documents', upload.single('file'), async (req, res) => {
    const user = resolveUser(req);
    const settings = store.getSettings(user.userId);
    try {
      let model = BUNDLED_CC_BY_PAPER;

      if (req.file) {
        model = await parseUploadedDocumentBuffer({
          filename: req.file.originalname,
          mimeType: req.file.mimetype,
          buffer: req.file.buffer,
          mockMode: settings.mockMode,
        });
      } else if (req.body?.useBundledFixture) {
        model = {
          ...BUNDLED_CC_BY_PAPER,
          id: `doc_${crypto.randomUUID().slice(0, 8)}`,
        };
      } else if (req.body?.url) {
        const ingested = await ingestFromRemoteUrl({
          url: String(req.body.url),
          mockMode: settings.mockMode,
        });
        model = ingested.model;
      } else {
        return res.status(400).json({ error: 'Provide a document URL, file upload, or bundled fixture flag.' });
      }

      const stored = store.saveDocument(user.userId, model);
      return res.status(201).json({ document: stored });
    } catch (err) {
      return res.status(400).json({ error: err instanceof Error ? err.message : 'Ingest failed' });
    }
  });

  // Delete-now privacy purge
  app.delete('/api/documents/:id', (req, res) => {
    const user = resolveUser(req);
    const ok = store.deleteDocumentNow(req.params.id, user.userId);
    if (!ok) return res.status(404).json({ error: 'Document not found' });
    return res.json({ deleted: true, documentId: req.params.id });
  });

  // Annotations: Research Notes & Concept Sketches
  app.get('/api/documents/:id/annotations', (req, res) => {
    const user = resolveUser(req);
    const doc = store.getDocument(req.params.id, user.userId);
    if (!doc) return res.status(404).json({ error: 'Document not found' });
    return res.json(store.getAnnotations(doc.id));
  });

  app.post('/api/documents/:id/notes', (req, res) => {
    const user = resolveUser(req);
    const doc = store.getDocument(req.params.id, user.userId);
    if (!doc) return res.status(404).json({ error: 'Document not found' });
    const body = String(req.body?.body ?? '').trim();
    if (!body) return res.status(400).json({ error: 'Note body is required.' });
    const colorTag = ['amber', 'blue', 'emerald', 'slate'].includes(req.body?.colorTag)
      ? (req.body.colorTag as 'amber' | 'blue' | 'emerald' | 'slate')
      : 'amber';
    const note = store.addNote({
      ownerId: user.userId,
      documentId: doc.id,
      citationKey: String(req.body?.citationKey ?? 'doc:p1/sec-intro'),
      page: Math.max(1, Number(req.body?.page ?? 1)),
      title: String(req.body?.title ?? 'Research Note'),
      body,
      colorTag,
    });
    return res.status(201).json({ note });
  });

  app.delete('/api/documents/:id/notes/:noteId', (req, res) => {
    const user = resolveUser(req);
    const doc = store.getDocument(req.params.id, user.userId);
    if (!doc) return res.status(404).json({ error: 'Document not found' });
    const ok = store.deleteNote(user.userId, doc.id, req.params.noteId);
    if (!ok) return res.status(404).json({ error: 'Note not found' });
    return res.json({ deleted: true });
  });

  app.post('/api/documents/:id/sketches', (req, res) => {
    const user = resolveUser(req);
    const doc = store.getDocument(req.params.id, user.userId);
    if (!doc) return res.status(404).json({ error: 'Document not found' });
    try {
      const strokes = SketchStrokeSchema.array().min(1).parse(req.body?.strokes);
      const sketch = store.addSketch({
        ownerId: user.userId,
        documentId: doc.id,
        citationKey: String(req.body?.citationKey ?? 'doc:p1/sec-intro'),
        page: Math.max(1, Number(req.body?.page ?? 1)),
        title: String(req.body?.title ?? 'Concept Sketch'),
        width: Math.max(120, Math.min(1200, Number(req.body?.width ?? 360))),
        height: Math.max(80, Math.min(800, Number(req.body?.height ?? 200))),
        strokes,
      });
      return res.status(201).json({ sketch });
    } catch (err) {
      return res.status(400).json({ error: err instanceof Error ? err.message : 'Invalid sketch data' });
    }
  });

  app.delete('/api/documents/:id/sketches/:sketchId', (req, res) => {
    const user = resolveUser(req);
    const doc = store.getDocument(req.params.id, user.userId);
    if (!doc) return res.status(404).json({ error: 'Document not found' });
    const ok = store.deleteSketch(user.userId, doc.id, req.params.sketchId);
    if (!ok) return res.status(404).json({ error: 'Sketch not found' });
    return res.json({ deleted: true });
  });

  // Platform-independent export of complete annotated research (HTML Notebook, Markdown+SVG, JSON Archive)
  app.get('/api/documents/:id/export', (req, res) => {
    const shareToken = typeof req.query.share === 'string' ? req.query.share : undefined;
    let doc = undefined;
    let video = undefined;

    if (shareToken) {
      const resolved = store.resolveShareLink(shareToken);
      if (!resolved.valid || resolved.document?.id !== req.params.id) {
        return res.status(403).json({ error: resolved.reason || 'Invalid share link' });
      }
      doc = resolved.document;
      video = resolved.video;
    } else {
      const user = resolveUser(req);
      doc = store.getDocument(req.params.id, user.userId);
      if (!doc) return res.status(404).json({ error: 'Document not found' });
      video = doc.latestVideoId ? store.getVideo(doc.latestVideoId) : undefined;
    }

    const { notes, sketches } = store.getAnnotations(doc.id);
    const format = String(req.query.format ?? 'html').toLowerCase();
    const safeSlug = doc.model.title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 48) || doc.id;

    if (format === 'json') {
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${safeSlug}-research-bundle.json"`);
      return res.send(buildJsonResearchArchive({ doc: doc.model, video, notes, sketches }));
    }

    if (format === 'md' || format === 'markdown') {
      res.setHeader('Content-Type', 'text/markdown; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${safeSlug}-notebook.md"`);
      return res.send(buildMarkdownNotebook({ doc: doc.model, video, notes, sketches }));
    }

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${safeSlug}-portable-notebook.html"`);
    return res.send(buildPortableHtmlNotebook({ doc: doc.model, video, notes, sketches }));
  });

  // Create & run a video generation job
  app.post('/api/jobs', async (req, res) => {
    const user = resolveUser(req);
    try {
      const documentId = String(req.body?.documentId ?? '');
      const doc = store.getDocument(documentId, user.userId);
      if (!doc) return res.status(404).json({ error: 'Document not found' });

      const depth = DepthSchema.parse(req.body?.depth ?? 'student');
      const lengthTarget = LengthTargetSchema.parse(req.body?.lengthTarget ?? '2min');
      const language = LanguageCodeSchema.parse(req.body?.language ?? 'en');
      const llmProvider = req.body?.llmProvider
        ? LLMProviderNameSchema.parse(req.body.llmProvider)
        : undefined;
      const ttsProvider = req.body?.ttsProvider
        ? TTSProviderNameSchema.parse(req.body.ttsProvider)
        : undefined;
      const simulateFailStage = req.body?.simulateFailStage as JobStageName | undefined;

      const job = store.createJob({
        ownerId: user.userId,
        documentId,
        depth,
        lengthTarget,
        language,
        llmProvider,
        ttsProvider,
      });

      const finished = await store.runJobPipeline(job.id, { simulateFailStage });
      const video = finished.videoId ? store.getVideo(finished.videoId) : undefined;
      return res.status(201).json({ job: finished, video });
    } catch (err) {
      return res.status(400).json({ error: err instanceof Error ? err.message : 'Job creation failed' });
    }
  });

  app.get('/api/jobs', (req, res) => {
    const user = resolveUser(req);
    res.json({ jobs: store.listJobs(user.userId) });
  });

  app.get('/api/jobs/:id', (req, res) => {
    const user = resolveUser(req);
    const job = store.getJob(req.params.id, user.userId);
    if (!job) return res.status(404).json({ error: 'Job not found' });
    const video = job.videoId ? store.getVideo(job.videoId) : undefined;
    return res.json({ job, video });
  });

  app.post('/api/jobs/:id/retry', async (req, res) => {
    const user = resolveUser(req);
    const job = store.getJob(req.params.id, user.userId);
    if (!job) return res.status(404).json({ error: 'Job not found' });
    const stage = (req.body?.stage as JobStageName | undefined) ?? job.failedStage ?? 'understand';
    const finished = await store.runJobPipeline(job.id, { resumeFromStage: stage });
    const video = finished.videoId ? store.getVideo(finished.videoId) : undefined;
    return res.json({ job: finished, video });
  });

  // Video artifacts, MP4 streaming, WebVTT captions, & Sources
  app.get('/api/videos/:id', (req, res) => {
    const user = resolveUser(req);
    const video = store.getVideo(req.params.id);
    if (!video) return res.status(404).json({ error: 'Video not found' });
    const doc = store.getDocument(video.documentId, user.userId);
    if (!doc) return res.status(403).json({ error: 'Access denied' });
    const annotations = store.getAnnotations(doc.id);
    return res.json({ video, document: doc, notes: annotations.notes, sketches: annotations.sketches });
  });

  app.get('/api/videos/:id/stream.mp4', (req, res) => {
    const videoDir = path.resolve(STORAGE_ROOT, 'videos', req.params.id);
    const mp4Path = path.resolve(videoDir, 'podcast.mp4');
    if (!mp4Path.startsWith(STORAGE_ROOT + path.sep) || !fs.existsSync(mp4Path)) {
      return res.status(404).json({ error: 'MP4 artifact not found' });
    }
    return res.sendFile(mp4Path, { headers: { 'Content-Type': 'video/mp4' } });
  });

  app.get('/api/videos/:id/captions.vtt', (req, res) => {
    const videoDir = path.resolve(STORAGE_ROOT, 'videos', req.params.id);
    const vttPath = path.resolve(videoDir, 'captions.vtt');
    if (!vttPath.startsWith(STORAGE_ROOT + path.sep) || !fs.existsSync(vttPath)) {
      return res.status(404).json({ error: 'Captions VTT not found' });
    }
    res.setHeader('Content-Type', 'text/vtt; charset=utf-8');
    return res.sendFile(vttPath);
  });

  app.get('/api/videos/:id/narration.wav', (req, res) => {
    const videoDir = path.resolve(STORAGE_ROOT, 'videos', req.params.id);
    const wavPath = path.resolve(videoDir, 'narration.wav');
    if (!wavPath.startsWith(STORAGE_ROOT + path.sep) || !fs.existsSync(wavPath)) {
      return res.status(404).json({ error: 'Narration audio not found' });
    }
    return res.sendFile(wavPath, { headers: { 'Content-Type': 'audio/wav' } });
  });

  // Grounded Q&A endpoint
  app.post('/api/videos/:id/qa', (req, res) => {
    const user = resolveUser(req);
    const video = store.getVideo(req.params.id);
    if (!video) return res.status(404).json({ error: 'Video not found' });
    const doc = store.getDocument(video.documentId, user.userId);
    if (!doc) return res.status(403).json({ error: 'Access denied' });

    const question = String(req.body?.question ?? '').trim();
    if (!question) return res.status(400).json({ error: 'Question text is required.' });

    const response = answerGroundedQuestion({
      question,
      doc: doc.model,
      clarifications: video.clarifications,
      scenes: video.scenes,
    });
    return res.json(response);
  });

  // Expiring share links (Viewer role)
  app.post('/api/videos/:id/share', (req, res) => {
    const user = resolveUser(req);
    const video = store.getVideo(req.params.id);
    if (!video) return res.status(404).json({ error: 'Video not found' });
    const doc = store.getDocument(video.documentId, user.userId);
    if (!doc) return res.status(403).json({ error: 'Access denied' });

    const expiresInHours = Number(req.body?.expiresInHours ?? 24);
    const link = store.createShareLink({
      ownerId: user.userId,
      documentId: doc.id,
      videoId: video.id,
      expiresInHours,
    });
    return res.status(201).json({ shareLink: link });
  });

  app.get('/api/share/:token', (req, res) => {
    const resolved = store.resolveShareLink(req.params.token);
    if (!resolved.valid) {
      return res.status(410).json({ error: resolved.reason });
    }
    return res.json({
      role: resolved.link!.role,
      expiresAt: resolved.link!.expiresAt,
      video: resolved.video,
      document: resolved.document,
      notes: resolved.notes ?? [],
      sketches: resolved.sketches ?? [],
    });
  });

  // Mount Vite in dev or serve built dist in production
  const isProd = process.env.NODE_ENV === 'production' && fs.existsSync(path.resolve('dist/index.html'));
  if (isProd) {
    app.use(express.static(path.resolve('dist')));
    app.get('/{*splat}', (_req, res) => {
      res.sendFile(path.resolve('dist/index.html'));
    });
  } else {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  }

  return { app, store };
}

// Start server when executed directly (avoid listening during unit test imports)
const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve('server.ts');
if (isMain) {
  createAppServer().then(({ app }) => {
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Drishya server listening on http://0.0.0.0:${PORT}`);
    });
  });
}
