import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import express, { type Request, type Response } from 'express';
import {
  explainLineageWithGemini,
  interpretQueryWithGemini,
  isGeminiConfigured,
  summarizeSearchWithGemini,
} from './server/ai.ts';
import { embedTexts, isEmbeddingRateLimitError } from './server/embeddings.ts';
import { buildDeterministicSearchAnswer } from './src/lib/explainLineage.ts';
import {
  createNeo4jRunnerFromEnv,
  Neo4jRepository,
  Neo4jUnavailableError,
  type PanjiRepository,
} from './server/neo4jRepo.ts';
import type { SemanticMatch } from './src/types/panji.ts';

const ROOT_DIR = path.resolve(import.meta.dirname);

function handleRouteError(res: Response, err: unknown, fallbackMessage: string) {
  if (err instanceof Neo4jUnavailableError) {
    res.status(503).json({
      error: err.message,
      code: err.code,
    });
    return;
  }
  console.error('[api] error:', err);
  res.status(500).json({ error: fallbackMessage });
}

export function createApiApp(repo?: PanjiRepository) {
  const repository: PanjiRepository =
    repo ?? new Neo4jRepository(createNeo4jRunnerFromEnv());

  const app = express();
  app.use(express.json({ limit: '32kb' }));

  app.get('/api/health', async (_req: Request, res: Response) => {
    try {
      const neoHealth = await repository.checkHealth();
      res.json({
        ok: true,
        ...neoHealth,
        aiAvailable: isGeminiConfigured(),
      });
    } catch (err) {
      res.json({
        ok: true,
        neo4jConfigured: true,
        neo4jConnected: false,
        neo4jError: (err as Error).message,
        aiAvailable: isGeminiConfigured(),
        semanticSearchAvailable: false,
        semanticSearchError: 'Neo4j is unavailable.',
        semanticProfilesEmbedded: 0,
        semanticProfilesTotal: 0,
        counts: null,
      });
    }
  });

  app.get('/api/filters', async (_req: Request, res: Response) => {
    try {
      const data = await repository.getFilterOptions();
      res.json(data);
    } catch (err) {
      handleRouteError(res, err, 'Failed to fetch filter metadata from Neo4j.');
    }
  });

  app.get('/api/search', async (req: Request, res: Response) => {
    try {
      const q = typeof req.query.q === 'string' ? req.query.q.slice(0, 240) : '';
      const village =
        typeof req.query.village === 'string' ? req.query.village.slice(0, 120) : undefined;
      const mool = typeof req.query.mool === 'string' ? req.query.mool.slice(0, 120) : undefined;
      const gotra = typeof req.query.gotra === 'string' ? req.query.gotra.slice(0, 120) : undefined;
      const useAi = req.query.useAi === 'true';
      const useSemantic = req.query.useSemantic !== 'false';
      const limit = Math.min(Math.max(Number(req.query.limit) || 40, 1), 100);
      const health = useSemantic ? await repository.checkHealth() : null;
      const semanticSearchAvailable = Boolean(health?.semanticSearchAvailable);
      let semanticSearchWarning = health?.semanticSearchWarning;
      let semanticMatches: SemanticMatch[] = [];
      if (q && semanticSearchAvailable) {
        try {
          const [embedding] = await embedTexts([q], 'RETRIEVAL_QUERY');
          semanticMatches = await repository.findSemanticMatches(embedding, 160);
        } catch (err) {
          if (!isEmbeddingRateLimitError(err)) throw err;
          console.warn('[api] Gemini embedding quota reached; returning exact-only search results.');
          semanticSearchWarning = [
            semanticSearchWarning,
            'Gemini embedding quota is currently exhausted; this search used exact matching only.',
          ]
            .filter(Boolean)
            .join(' ');
        }
      }

      let customInterpretation;
      if (useAi && q.trim().length > 0 && isGeminiConfigured()) {
        const wordCount = q.trim().split(/\s+/).length;
        if (wordCount >= 3) {
          const gotraNames = await repository.getGotraNames();
          customInterpretation = (await interpretQueryWithGemini(q, gotraNames)) ?? undefined;
        }
      }

      const result = await repository.searchPersons(
        q,
        { village, mool, gotra },
        customInterpretation,
        limit,
        semanticMatches
      );

      const hasSearchInput = Boolean(q.trim() || village || mool || gotra);
      const answer = hasSearchInput
        ? useAi && isGeminiConfigured()
          ? await summarizeSearchWithGemini(
              q,
              result.candidates,
              result.totalMatches,
              result.appliedFilters
            )
          : buildDeterministicSearchAnswer(
              q,
              result.candidates,
              result.totalMatches,
              result.appliedFilters
            )
        : undefined;

      res.json({
        ...result,
        answer,
        semanticSearchAvailable,
        semanticSearchUsed: semanticMatches.length > 0,
        semanticSearchError: semanticSearchAvailable ? undefined : health?.semanticSearchError,
        semanticSearchWarning,
      });
    } catch (err) {
      handleRouteError(res, err, 'Failed to execute genealogy search in Neo4j.');
    }
  });

  app.post('/api/ai/answer', async (req: Request, res: Response) => {
    try {
      const body = (req.body || {}) as {
        query?: unknown;
        candidateIds?: unknown;
        totalMatches?: unknown;
        appliedFilters?: { village?: unknown; mool?: unknown; gotra?: unknown };
      };

      const query = typeof body.query === 'string' ? body.query.trim().slice(0, 240) : '';
      const candidateIds = Array.isArray(body.candidateIds)
        ? body.candidateIds
            .map((id) => String(id).trim())
            .filter((id) => id.length > 0 && id.length <= 64)
            .slice(0, 6)
        : [];
      const totalMatches = Math.max(0, Number(body.totalMatches) || candidateIds.length);
      const appliedFilters = {
        village:
          typeof body.appliedFilters?.village === 'string'
            ? body.appliedFilters.village.slice(0, 120)
            : undefined,
        mool:
          typeof body.appliedFilters?.mool === 'string'
            ? body.appliedFilters.mool.slice(0, 120)
            : undefined,
        gotra:
          typeof body.appliedFilters?.gotra === 'string'
            ? body.appliedFilters.gotra.slice(0, 120)
            : undefined,
      };

      const contextCandidates = await repository.getAnswerContextByIds(candidateIds);
      const answer = await summarizeSearchWithGemini(
        query,
        contextCandidates,
        totalMatches,
        appliedFilters
      );
      res.json(answer);
    } catch (err) {
      handleRouteError(res, err, 'Failed to generate concise search answer.');
    }
  });

  app.get('/api/person/:id/lineage', async (req: Request, res: Response) => {
    try {
      const id = String(req.params.id || '').trim();
      if (!id || id.length > 64) {
        res.status(400).json({ error: 'Invalid person identifier.' });
        return;
      }
      const lineage = await repository.getLineage(id);
      if (!lineage) {
        res.status(404).json({ error: 'Person record not found in Neo4j graph.' });
        return;
      }
      res.json(lineage);
    } catch (err) {
      handleRouteError(res, err, 'Failed to query lineage graph in Neo4j.');
    }
  });

  app.get('/api/person/:id/similar', async (req: Request, res: Response) => {
    try {
      const personId = String(req.params.id || '').trim();
      if (!personId || personId.length > 64) {
        res.status(400).json({ error: 'Invalid person identifier.' });
        return;
      }

      const health = await repository.checkHealth();
      if (!health.neo4jConfigured) {
        throw new Neo4jUnavailableError(
          'NEO4J_NOT_CONFIGURED',
          'Neo4j is not configured for this application.'
        );
      }
      if (!health.neo4jConnected) {
        throw new Neo4jUnavailableError('NEO4J_UNAVAILABLE', 'Neo4j is unavailable.');
      }
      if (!health.semanticSearchAvailable) {
        res.json({
          available: false,
          error: health.semanticSearchError,
          candidates: [],
        });
        return;
      }

      const limit = Math.min(Math.max(Number(req.query.limit) || 5, 1), 10);
      const candidates = await repository.getSimilarPersons(personId, limit);
      if (!candidates) {
        res.json({
          available: false,
          error: 'This person profile is not embedded yet; similar-record suggestions are unavailable.',
          warning: health.semanticSearchWarning,
          candidates: [],
        });
        return;
      }
      res.json({
        available: true,
        warning: health.semanticSearchWarning,
        candidates,
      });
    } catch (err) {
      handleRouteError(res, err, 'Failed to find semantically similar ancestor records.');
    }
  });

  app.post('/api/ai/explain', async (req: Request, res: Response) => {
    try {
      const body = (req.body || {}) as { personId?: unknown; query?: unknown };
      const personId = typeof body.personId === 'string' ? body.personId.trim() : '';
      const query = typeof body.query === 'string' ? body.query.trim().slice(0, 240) : undefined;

      if (!personId || personId.length > 64) {
        res.status(400).json({ error: 'Valid personId is required.' });
        return;
      }

      const lineage = await repository.getLineage(personId);
      if (!lineage) {
        res.status(404).json({ error: 'Person record not found in Neo4j graph.' });
        return;
      }

      const explanation = await explainLineageWithGemini(lineage, query);
      res.json(explanation);
    } catch (err) {
      handleRouteError(res, err, 'Failed to generate lineage explanation.');
    }
  });

  app.get('/api/neo4j/relationship', async (req: Request, res: Response) => {
    try {
      const fromId = typeof req.query.from === 'string' ? req.query.from.trim() : '';
      const toId = typeof req.query.to === 'string' ? req.query.to.trim() : '';
      if (!fromId || !toId || fromId.length > 64 || toId.length > 64) {
        res.status(400).json({ error: 'Both "from" and "to" person IDs are required.' });
        return;
      }

      const pathResult = await repository.findShortestRelationship(fromId, toId);
      if (!pathResult) {
        res.status(404).json({ error: 'One or both person records were not found in Neo4j.' });
        return;
      }
      res.json(pathResult);
    } catch (err) {
      handleRouteError(res, err, 'Failed to compute shortest relationship path in Neo4j.');
    }
  });

  app.get('/api/neo4j/mools-gotras', async (_req: Request, res: Response) => {
    try {
      const data = await repository.getMoolsAndGotras();
      res.json(data);
    } catch (err) {
      handleRouteError(res, err, 'Failed to load Mool and Gotra graph from Neo4j.');
    }
  });

  app.get('/api/neo4j/coverage', async (req: Request, res: Response) => {
    try {
      const limit = Math.min(Math.max(Number(req.query.limit) || 24, 1), 60);
      const data = await repository.getTreeCoverage(limit);
      res.json(data);
    } catch (err) {
      handleRouteError(res, err, 'Failed to compute family tree coverage in Neo4j.');
    }
  });

  return app;
}

async function startServer() {
  const runner = createNeo4jRunnerFromEnv();
  const repo = new Neo4jRepository(runner);
  const app = createApiApp(repo);
  const port = Number(process.env.PORT || 3000);
  const distDir = path.join(ROOT_DIR, 'dist');
  const isProd =
    process.env.NODE_ENV === 'production' ||
    (process.env.DEV_MODE !== 'true' && fs.existsSync(path.join(distDir, 'index.html')));

  if (!isProd) {
    const { createServer: createViteServer } = await import('vite');
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(distDir));
    app.get('*', (_req: Request, res: Response) => {
      res.sendFile(path.join(distDir, 'index.html'));
    });
  }

  const server = app.listen(port, '0.0.0.0', () => {
    console.log(
      `PAAG Mithila Panji Search listening on http://localhost:${port} (Neo4j configured: ${Boolean(runner)})`
    );
  });

  const shutdown = async () => {
    server.close();
    if (runner) {
      await runner.close().catch(() => {});
    }
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

const isDirectRun =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename);

if (isDirectRun) {
  startServer().catch((err) => {
    console.error('Failed to start server:', err);
    process.exit(1);
  });
}
