import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import {
  buildFixtureStoryboard,
  BUNDLED_CC_BY_PAPER,
  BUNDLED_CLARIFICATIONS,
  BUNDLED_UNDERSTAND_OUTPUT,
  FIXTURE_QA_EVAL_SET,
} from '../server/fixtures/paper.ts';
import {
  buildValidCitationSet,
  enforceStoryboardGrounding,
  extractAllowedNumbers,
  findUngroundedNumbers,
  processClarificationSources,
  resolveAndVerifyChartScene,
} from '../server/pipeline/grounding.ts';
import {
  extractTextFromPdfBuffer,
  isReadableText,
  normalizeDocumentUrlInput,
  parseUploadedDocumentBuffer,
  validateRemoteDocumentUrl,
} from '../server/pipeline/ingest.ts';
import {
  buildJsonResearchArchive,
  buildMarkdownNotebook,
  buildPortableHtmlNotebook,
} from '../server/pipeline/export.ts';
import { executeWithProviderChain, TTS_PROVIDERS } from '../server/pipeline/providers.ts';
import { answerGroundedQuestion, EXACT_QA_REFUSAL } from '../server/pipeline/qa.ts';
import { translateStoryboard, translateWithGuard } from '../server/pipeline/translation.ts';
import { DEFAULT_USER_ID, DrishyaStore } from '../server/store.ts';
import {
  StoryboardSceneSchema,
  SUPPORTED_LANGUAGES,
  UnderstandOutputSchema,
} from '../server/types.ts';

test('1. Grounding: every scene has valid citations and uncited sentences are dropped', () => {
  const doc = BUNDLED_CC_BY_PAPER;
  const clarifications = processClarificationSources(BUNDLED_CLARIFICATIONS);
  const storyboard = buildFixtureStoryboard(doc, 'student', '2min');

  // Inject an uncited sentence into scene 1
  const polluted = storyboard.map((s, idx) =>
    idx === 0
      ? {
          ...s,
          sentences: [
            ...s.sentences,
            {
              id: 'injected-uncited',
              text: 'This uncited claim must be stripped before rendering.',
              citations: [],
            },
          ],
        }
      : s
  );

  const result = enforceStoryboardGrounding(polluted, doc, clarifications);
  assert.equal(result.droppedUncitedSentences, 1);

  const validSet = buildValidCitationSet(doc, clarifications);
  for (const scene of result.scenes) {
    assert.ok(scene.citations.length >= 1, `Scene ${scene.id} must have >=1 citation`);
    for (const cit of scene.citations) {
      assert.ok(validSet.has(cit), `Citation ${cit} must resolve`);
    }
    assert.ok(
      !scene.narration.includes('This uncited claim must be stripped'),
      'Uncited sentence must not survive in narration'
    );
  }
});

test('2. Chart accuracy: rendered chart values equal parsed table values and mismatch fails scene', () => {
  const doc = BUNDLED_CC_BY_PAPER;
  const table1 = doc.tables[0];
  const scenes = buildFixtureStoryboard(doc, 'student', '2min');
  const chartScene = scenes.find((s) => s.visualSpec.kind === 'chart')!;

  const { scene: resolved, report } = resolveAndVerifyChartScene(chartScene, doc);
  assert.ok(report?.verified);
  assert.equal(report?.checkedCells, table1.rows.length * 2);

  // Inject mismatching chart data and verify it fails
  const corruptedScene = {
    ...resolved,
    visualSpec: {
      ...resolved.visualSpec,
      kind: 'chart' as const,
      resolvedSeries: [
        { label: 'ConvLSTM', values: { RMSE_5d: 999.9, VRAM_GB: 14.2 } },
      ],
    },
  };
  const failed = resolveAndVerifyChartScene(corruptedScene as typeof chartScene, doc);
  assert.equal(failed.report?.verified, false);
  assert.ok((failed.report?.mismatches.length ?? 0) > 0);
});

test('3. Number guard: no number in narration that is not in document or cited sources', () => {
  const doc = BUNDLED_CC_BY_PAPER;
  const clarifications = processClarificationSources(BUNDLED_CLARIFICATIONS);
  const allowed = extractAllowedNumbers(doc, clarifications);

  assert.deepEqual(
    findUngroundedNumbers('MonsoonFormer achieves 11.4 mm/day RMSE and 9.6 GB VRAM.', allowed),
    []
  );
  assert.deepEqual(
    findUngroundedNumbers('MonsoonFormer achieves 87.65 mm/day RMSE.', allowed),
    ['87.65']
  );

  // Also ensure enforceStoryboardGrounding drops sentences with hallucinated numbers
  const scenes = buildFixtureStoryboard(doc, 'student', '2min');
  const injected = scenes.map((s, idx) =>
    idx === 0
      ? {
          ...s,
          sentences: [
            ...s.sentences,
            {
              id: 'bad-num',
              text: 'It improved rainfall speed by 73.92 percent in 1987.',
              citations: ['doc:p1/sec-intro'],
            },
          ],
        }
      : s
  );
  const guarded = enforceStoryboardGrounding(injected, doc, clarifications);
  assert.ok(guarded.numberGuardViolations >= 2);
  assert.ok(!guarded.scenes[0].narration.includes('73.92'));
});

test('4. Source tiers: ranking, lower confidence label, differing view flag, quote <= 25 words', () => {
  const longQuote = Array.from({ length: 34 }, (_, i) => `word${i}`).join(' ');
  const ranked = processClarificationSources([
    ...BUNDLED_CLARIFICATIONS,
    {
      id: 'extra-long',
      hardPartId: 'hp-1',
      term: 'Test',
      tier: 3,
      providerName: 'Web',
      title: 'Long Quote',
      url: 'https://example.org/long',
      year: 2025,
      relevanceScore: 0.99,
      quote: longQuote,
      confidenceLabel: 'high' as const,
      contradictsPaper: false,
    },
  ]);

  assert.equal(ranked[0].tier, 1);
  const differing = ranked.find((s) => s.contradictsPaper);
  assert.equal(differing?.viewLabel, 'Differing view');

  const tier3Items = ranked.filter((s) => s.tier === 3);
  for (const item of tier3Items) {
    assert.equal(item.confidenceLabel, 'lower confidence');
    assert.ok(item.quote.split(/\s+/).length <= 25);
  }
});

test('5. Translation guard: technical terms, numbers, units, and LaTeX survive En->Hi/Ta/Ur unchanged', () => {
  const sample = 'MonsoonFormer hits 11.4 mm/day RMSE with 9.6 GB VRAM and $\\alpha_{ij}$ attention.';
  for (const lang of ['hi', 'ta', 'ur'] as const) {
    const { translated, guardVerified } = translateWithGuard(sample, lang);
    assert.equal(guardVerified, true, `Guard failed for ${lang}`);
    assert.ok(translated.includes('MonsoonFormer'));
    assert.ok(translated.includes('11.4 mm/day'));
    assert.ok(translated.includes('9.6 GB'));
    assert.ok(translated.includes('$\\alpha_{ij}$'));
  }

  const scenes = buildFixtureStoryboard(BUNDLED_CC_BY_PAPER, 'student', '2min');
  const urRes = translateStoryboard(scenes, 'ur');
  assert.equal(urRes.dir, 'rtl');
  assert.equal(urRes.guardVerified, true);
});

test('6. Storyboard schema validation & length targets within +/-15%', () => {
  const targets: Array<{ key: '2min' | '5min' | '10min'; targetSec: number }> = [
    { key: '2min', targetSec: 120 },
    { key: '5min', targetSec: 300 },
    { key: '10min', targetSec: 600 },
  ];

  for (const { key, targetSec } of targets) {
    const scenes = buildFixtureStoryboard(BUNDLED_CC_BY_PAPER, 'student', key);
    for (const sc of scenes) {
      StoryboardSceneSchema.parse(sc);
    }
    const total = scenes.reduce((sum, s) => sum + s.durationSeconds, 0);
    const minAllowed = targetSec * 0.85;
    const maxAllowed = targetSec * 1.15;
    assert.ok(
      total >= minAllowed && total <= maxAllowed,
      `Length ${key} total ${total}s outside [${minAllowed}, ${maxAllowed}]`
    );
  }
});

test('7. Q&A: fixture question set resolves expected citations & unanswerable returns exact refusal', () => {
  const clarifications = processClarificationSources(BUNDLED_CLARIFICATIONS);
  const scenes = buildFixtureStoryboard(BUNDLED_CC_BY_PAPER, 'student', '2min');

  for (const item of FIXTURE_QA_EVAL_SET) {
    const res = answerGroundedQuestion({
      question: item.question,
      doc: BUNDLED_CC_BY_PAPER,
      clarifications,
      scenes,
    });
    if (item.shouldAnswer) {
      assert.equal(res.answered, true);
      const cited = res.sentences.flatMap((s) => s.citations);
      assert.ok(
        item.expectedCitations.some((exp) => cited.includes(exp)),
        `Expected one of ${item.expectedCitations} in ${cited}`
      );
    } else {
      assert.equal(res.answered, false);
      assert.equal(res.refusalText, EXACT_QA_REFUSAL);
    }
  }
});

test('8. Privacy: retention deletes DB rows + objects, share links expire, logs contain no doc text', async () => {
  const store = new DrishyaStore();
  const docCopy = { ...BUNDLED_CC_BY_PAPER, id: 'doc_privacy_test' };
  store.saveDocument(DEFAULT_USER_ID, docCopy);
  const job = store.createJob({
    ownerId: DEFAULT_USER_ID,
    documentId: docCopy.id,
    depth: 'student',
    lengthTarget: '2min',
    language: 'en',
  });
  await store.runJobPipeline(job.id);
  const createdJob = store.getJob(job.id)!;
  assert.ok(createdJob.videoId);

  // Verify audit logs contain zero document text
  const logs = store.getAuditLogs(DEFAULT_USER_ID);
  for (const l of logs) {
    assert.ok(!l.note.includes('Western Ghats escarpments'));
    assert.equal(l.metadataRedacted, true);
  }

  // Share link expiry check
  const share = store.createShareLink({
    ownerId: DEFAULT_USER_ID,
    documentId: docCopy.id,
    videoId: createdJob.videoId!,
    expiresInHours: -1, // Already expired
  });
  const resolved = store.resolveShareLink(share.token);
  assert.equal(resolved.valid, false);

  // Retention sweep check using future date
  const futureDate = new Date(Date.now() + 45 * 86400 * 1000);
  const swept = store.runRetentionSweep(futureDate);
  assert.ok(swept.deletedDocuments.includes(docCopy.id));
  assert.equal(store.getDocument(docCopy.id), undefined);
  assert.equal(store.getVideo(createdJob.videoId!), undefined);
  const videoDir = path.resolve(process.cwd(), 'data/storage/videos', createdJob.videoId!);
  assert.equal(fs.existsSync(videoDir), false);
});

test('9. Provider switching & TTS capability contracts + SSRF guard', async () => {
  const models = {
    mock: 'mock-v1',
    gemini: 'gemini-4-hydrogen',
    anthropic: 'claude-sonnet-4-20250514',
    openai: 'gpt-4.1-mini',
    ollama: 'llama3.2:latest',
  };

  for (const provider of ['mock', 'gemini', 'anthropic', 'openai', 'ollama'] as const) {
    const res = await executeWithProviderChain({
      primary: provider,
      fallbackChain: ['mock'],
      models,
      mockMode: true,
      promptVersion: 'v1.0',
      systemPrompt: 'sys',
      userPrompt: 'usr',
      schema: UnderstandOutputSchema,
      mockFallback: () => BUNDLED_UNDERSTAND_OUTPUT,
    });
    assert.equal(res.data.claims.length, 3);
  }

  // TTS contracts for all 12 languages
  assert.equal(SUPPORTED_LANGUAGES.length, 12);
  const paTts = TTS_PROVIDERS.mock.synthesizeInfo('pa', 120);
  assert.equal(paTts.captionsOnly, true);
  const hiTts = TTS_PROVIDERS.piper.synthesizeInfo('hi', 120);
  assert.equal(hiTts.captionsOnly, false);

  // SSRF guard
  assert.throws(() => validateRemoteDocumentUrl('http://127.0.0.1:8080/secret'));
  assert.throws(() => validateRemoteDocumentUrl('http://169.254.169.254/latest/meta-data/'));
});

test('10. End-to-end mock pipeline: English & Hindi MP4 with spoken audio + WAV + WebVTT + stage retry', async () => {
  const { execFileSync } = await import('node:child_process');
  const store = new DrishyaStore();
  const doc = { ...BUNDLED_CC_BY_PAPER, id: 'doc_e2e_test' };
  store.saveDocument(DEFAULT_USER_ID, doc);

  // Test stage failure + resume/retry
  const failedJob = store.createJob({
    ownerId: DEFAULT_USER_ID,
    documentId: doc.id,
    depth: 'student',
    lengthTarget: '2min',
    language: 'hi',
  });
  const afterFail = await store.runJobPipeline(failedJob.id, { simulateFailStage: 'plan' });
  assert.equal(afterFail.status, 'failed');
  assert.equal(afterFail.failedStage, 'plan');

  const retried = await store.runJobPipeline(failedJob.id, { resumeFromStage: 'plan' });
  assert.equal(retried.status, 'ready');
  assert.ok(retried.videoId);

  const video = store.getVideo(retried.videoId!)!;
  assert.equal(video.language, 'hi');
  assert.equal(video.translationGuardVerified, true);
  assert.equal(video.audioUrl, `/api/videos/${video.id}/narration.wav`);

  const mp4Path = path.resolve(process.cwd(), 'data/storage/videos', video.id, 'podcast.mp4');
  const vttPath = path.resolve(process.cwd(), 'data/storage/videos', video.id, 'captions.vtt');
  const wavPath = path.resolve(process.cwd(), 'data/storage/videos', video.id, 'narration.wav');
  assert.ok(fs.existsSync(mp4Path), 'MP4 file must exist on disk');
  assert.ok(fs.statSync(mp4Path).size > 1000, 'MP4 must be non-empty');
  assert.ok(fs.existsSync(vttPath), 'WebVTT file must exist on disk');
  assert.ok(fs.existsSync(wavPath), 'Narration WAV file must exist on disk');
  assert.ok(fs.statSync(wavPath).size > 100000, 'Narration WAV must contain full audio track');

  // Verify WAV contains audible non-zero PCM speech signal beyond the 44-byte RIFF header
  const wavBuf = fs.readFileSync(wavPath);
  let maxSample = 0;
  for (let i = 44; i + 1 < Math.min(wavBuf.length, 48000 * 6); i += 2) {
    const sample = Math.abs(wavBuf.readInt16LE(i));
    if (sample > maxSample) maxSample = sample;
  }
  assert.ok(maxSample > 500, `Expected audible speech PCM waveform amplitude (>500), got ${maxSample}`);

  // Verify MP4 container has both video and audio streams
  const probe = execFileSync('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'stream=codec_type,codec_name',
    '-of',
    'default=noprint_wrappers=1:nokey=1',
    mp4Path,
  ]).toString();
  assert.ok(probe.includes('video'), 'MP4 must include a video stream');
  assert.ok(probe.includes('audio'), 'MP4 must include an audio narration stream');

  // Verify captions_only language completes cleanly with silent audio track
  const paJob = store.createJob({
    ownerId: DEFAULT_USER_ID,
    documentId: doc.id,
    depth: 'student',
    lengthTarget: '2min',
    language: 'pa',
  });
  const paDone = await store.runJobPipeline(paJob.id);
  assert.equal(paDone.status, 'ready');
  const paVideo = store.getVideo(paDone.videoId!)!;
  assert.equal(paVideo.languageCapability, 'captions_only');

  // Clean up test doc
  assert.equal(store.deleteDocumentNow(doc.id, DEFAULT_USER_ID), true);
});

test('11. Dynamic non-fixture document ingest + URL normalization produces its own grounded storyboard', async () => {
  assert.equal(normalizeDocumentUrlInput('10.1038/s41586-024-07140-6'), 'https://doi.org/10.1038/s41586-024-07140-6');
  assert.equal(normalizeDocumentUrlInput('arxiv:1706.03762'), 'https://arxiv.org/abs/1706.03762');

  const sampleHtml = `
    <html>
      <head>
        <title>Quantum Error Mitigation on Neutral Atom Arrays</title>
        <meta name="citation_author" content="Elena Vance" />
        <meta name="citation_publication_date" content="2025" />
      </head>
      <body>
        <main>
          <h2>1. Introduction</h2>
          <p>Neutral atom quantum processors exhibit correlated Rydberg blockade errors that scale across 256 physical qubits during multi-round entangling gates.</p>
          <h2>2. Zero-Noise Extrapolation Method</h2>
          <p>We apply pulse-stretching noise amplification factors of 1.0 and 1.6 combined with randomized Pauli compilation to reduce logical infidelity by 42 percent.</p>
          <table>
            <caption>Table 1: Logical Fidelity Comparison</caption>
            <tr><th>Protocol</th><th>Fidelity_pct</th><th>Shots_k</th></tr>
            <tr><td>Baseline</td><td>81.4</td><td>12</td></tr>
            <tr><td>Pulse-ZNE</td><td>94.2</td><td>12</td></tr>
          </table>
          <h2>3. Limitations</h2>
          <p>Classical post-processing overhead increases quadratically beyond 400 qubits when syndrome measurement latency exceeds coherence time.</p>
        </main>
      </body>
    </html>
  `;

  const parsedDoc = await parseUploadedDocumentBuffer({
    filename: 'quantum_zne.html',
    mimeType: 'text/html',
    buffer: Buffer.from(sampleHtml, 'utf8'),
    mockMode: true,
  });

  assert.equal(parsedDoc.title, 'Quantum Error Mitigation on Neutral Atom Arrays');
  assert.ok(!parsedDoc.title.includes('MonsoonFormer'));
  assert.equal(parsedDoc.tables.length, 1);
  assert.equal(parsedDoc.tables[0].rows[1].Fidelity_pct, 94.2);

  const store = new DrishyaStore();
  store.saveDocument(DEFAULT_USER_ID, parsedDoc);
  const job = store.createJob({
    ownerId: DEFAULT_USER_ID,
    documentId: parsedDoc.id,
    depth: 'student',
    lengthTarget: '2min',
    language: 'en',
  });
  const finished = await store.runJobPipeline(job.id);
  assert.equal(finished.status, 'ready');
  const video = store.getVideo(finished.videoId!)!;
  assert.equal(video.droppedUncitedSentences, 0);
  assert.equal(video.numberGuardViolations, 0);
  assert.ok(video.scenes.some((s) => s.narration.includes('Quantum Error Mitigation') || s.narration.includes('Rydberg')));
  assert.ok(!video.scenes.some((s) => s.narration.includes('Western Ghats')));
  assert.ok(video.chartAccuracyReport.every((r) => r.verified));

  assert.equal(store.deleteDocumentNow(parsedDoc.id, DEFAULT_USER_ID), true);
});

test('12. Notes, sketches, share link annotations, and platform-independent portable exports', async () => {
  const store = new DrishyaStore();
  const docCopy = { ...BUNDLED_CC_BY_PAPER, id: 'doc_annotations_test' };
  store.saveDocument(DEFAULT_USER_ID, docCopy);

  const job = store.createJob({
    ownerId: DEFAULT_USER_ID,
    documentId: docCopy.id,
    depth: 'student',
    lengthTarget: '2min',
    language: 'en',
  });
  const finished = await store.runJobPipeline(job.id);
  const video = store.getVideo(finished.videoId!)!;

  const note = store.addNote({
    ownerId: DEFAULT_USER_ID,
    documentId: docCopy.id,
    citationKey: 'doc:p5/table-1',
    page: 5,
    title: 'Benchmark check <script>alert(1)</script>',
    body: 'Verified 11.4 mm/day RMSE & 9.6 GB VRAM against Table 1.',
    colorTag: 'amber',
  });

  const sketch = store.addSketch({
    ownerId: DEFAULT_USER_ID,
    documentId: docCopy.id,
    citationKey: 'doc:p3/sec-arch',
    page: 3,
    title: 'Sparse attention window',
    width: 360,
    height: 180,
    strokes: [
      {
        color: '#1d4ed8',
        width: 3,
        points: [
          { x: 20, y: 30 },
          { x: 140, y: 95 },
          { x: 280, y: 40 },
        ],
      },
    ],
  });

  const listed = store.listDocuments(DEFAULT_USER_ID).find((i) => i.document.id === docCopy.id);
  assert.equal(listed?.notesCount, 1);
  assert.equal(listed?.sketchesCount, 1);

  const share = store.createShareLink({
    ownerId: DEFAULT_USER_ID,
    documentId: docCopy.id,
    videoId: video.id,
    expiresInHours: 12,
  });
  const resolved = store.resolveShareLink(share.token);
  assert.equal(resolved.valid, true);
  assert.equal(resolved.notes?.length, 1);
  assert.equal(resolved.sketches?.length, 1);

  const annotations = store.getAnnotations(docCopy.id);
  const htmlExport = buildPortableHtmlNotebook({
    doc: docCopy,
    video,
    notes: annotations.notes,
    sketches: annotations.sketches,
  });
  assert.ok(htmlExport.includes('<!doctype html>'));
  assert.ok(!htmlExport.includes('<script>alert(1)</script>'), 'HTML export must escape raw script tags');
  assert.ok(htmlExport.includes('&lt;script&gt;alert(1)&lt;/script&gt;'));
  assert.ok(htmlExport.includes('<svg'));
  assert.ok(htmlExport.includes('<polyline'));
  assert.ok(htmlExport.includes('Verified 11.4 mm/day RMSE'));

  const mdExport = buildMarkdownNotebook({
    doc: docCopy,
    video,
    notes: annotations.notes,
    sketches: annotations.sketches,
  });
  assert.ok(mdExport.includes('## 1. Annotated Research Notes (1)'));
  assert.ok(mdExport.includes('Sparse attention window'));
  assert.ok(mdExport.includes('<svg'));

  const jsonExport = JSON.parse(
    buildJsonResearchArchive({
      doc: docCopy,
      video,
      notes: annotations.notes,
      sketches: annotations.sketches,
    })
  );
  assert.equal(jsonExport.schemaVersion, 'drishya-research-bundle/v1');
  assert.equal(jsonExport.notes[0].id, note.id);
  assert.equal(jsonExport.sketches[0].id, sketch.id);

  assert.equal(store.deleteDocumentNow(docCopy.id, DEFAULT_USER_ID), true);
  const afterDelete = store.getAnnotations(docCopy.id);
  assert.equal(afterDelete.notes.length, 0);
  assert.equal(afterDelete.sketches.length, 0);
});

test('13. Layout-aware PDF extraction (PDF.js) avoids gibberish and extracts real pages & text', async () => {
  const zlib = await import('node:zlib');

  // Verify gibberish / ToUnicode cipher / raw PDF syntax detector rejects corrupted streams
  assert.equal(isReadableText('endobj FlateDecode /Filter /Length 2491 xref startxref'), false);
  assert.equal(isReadableText('xkqp ztrw bfgm pqrs vbnm qzxc wdfg klmn'), false);
  assert.equal(
    isReadableText('Sparse attention transformers reduce computational complexity across spatial rainfall grids.'),
    true
  );

  // Build a genuine 2-page compressed FlateDecode PDF buffer using standard Type1 Helvetica
  const page1Stream = zlib.deflateSync(
    Buffer.from(
      `BT\n/F1 16 Tf\n72 720 Td\n(Adaptive Coastal Wind Forecasting Study) Tj\n` +
        `/F1 11 Tf\n0 -35 Td\n(1. Introduction) Tj\n` +
        `0 -20 Td\n(Coastal turbine arrays require accurate twelve-hour wind ramp forecasts across offshore basins.) Tj\n` +
        `0 -18 Td\n(Traditional numerical weather prediction suffers from coarse boundary-layer resolution.) Tj\nET`,
      'latin1'
    )
  );
  const page2Stream = zlib.deflateSync(
    Buffer.from(
      `BT\n/F1 12 Tf\n72 720 Td\n(2. Experimental Results) Tj\n` +
        `/F1 11 Tf\n0 -25 Td\n(Across 420 offshore storm events, WindGraphNet achieved 1.84 meters per second root mean square error.) Tj\nET`,
      'latin1'
    )
  );

  const objects: Buffer[] = [
    Buffer.from('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n', 'latin1'),
    Buffer.from('2 0 obj\n<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>\nendobj\n', 'latin1'),
    Buffer.from('3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>\nendobj\n', 'latin1'),
    Buffer.from('4 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>\nendobj\n', 'latin1'),
    Buffer.from('5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n', 'latin1'),
    Buffer.concat([
      Buffer.from(`6 0 obj\n<< /Length ${page1Stream.length} /Filter /FlateDecode >>\nstream\n`, 'latin1'),
      page1Stream,
      Buffer.from('\nendstream\nendobj\n', 'latin1'),
    ]),
    Buffer.concat([
      Buffer.from(`7 0 obj\n<< /Length ${page2Stream.length} /Filter /FlateDecode >>\nstream\n`, 'latin1'),
      page2Stream,
      Buffer.from('\nendstream\nendobj\n', 'latin1'),
    ]),
  ];

  const header = Buffer.from('%PDF-1.4\n', 'latin1');
  const offsets: number[] = [];
  let cursor = header.length;
  for (const obj of objects) {
    offsets.push(cursor);
    cursor += obj.length;
  }
  const xrefStart = cursor;
  const xrefLines = [
    `xref\n0 ${objects.length + 1}\n`,
    '0000000000 65535 f \n',
    ...offsets.map((off) => `${String(off).padStart(10, '0')} 00000 n \n`),
    `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF\n`,
  ];
  const pdfBuffer = Buffer.concat([header, ...objects, Buffer.from(xrefLines.join(''), 'latin1')]);

  const extracted = await extractTextFromPdfBuffer(pdfBuffer);
  assert.equal(extracted.ocrUsed, false);
  assert.equal(extracted.pageCount, 2);
  assert.ok(extracted.text.includes('Coastal turbine arrays require accurate twelve-hour wind ramp forecasts'));
  assert.ok(extracted.text.includes('WindGraphNet achieved 1.84 meters per second'));

  const doc = await parseUploadedDocumentBuffer({
    filename: 'coastal_wind.pdf',
    mimeType: 'application/pdf',
    buffer: pdfBuffer,
    mockMode: true,
  });
  assert.equal(doc.ocrUsed, false);
  assert.ok(doc.paragraphs.some((p) => p.page === 1 && p.text.includes('Coastal turbine arrays')));
  assert.ok(doc.paragraphs.some((p) => p.page === 2 && p.text.includes('WindGraphNet')));
  assert.ok(!doc.paragraphs.some((p) => p.text.includes('FlateDecode') || p.text.includes('endobj')));
});


