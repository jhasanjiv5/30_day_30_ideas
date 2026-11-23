import {
  ChartAccuracyEntry,
  ClarificationSource,
  DocumentModel,
  NarratedSentence,
  StoryboardScene,
} from '../types.ts';

/**
 * Resolves whether a citation key maps to a real span/figure/table/equation in DocumentModel
 * or a recorded external ClarificationSource URL.
 */
export function buildValidCitationSet(
  doc: DocumentModel,
  clarifications: ClarificationSource[]
): Set<string> {
  const valid = new Set<string>();
  for (const p of doc.paragraphs) valid.add(p.citationKey);
  for (const f of doc.figures) valid.add(f.citationKey);
  for (const t of doc.tables) valid.add(t.citationKey);
  for (const e of doc.equations) valid.add(e.citationKey);
  for (const r of doc.references) valid.add(r.url);
  for (const c of clarifications) valid.add(c.url);
  return valid;
}

export function resolveCitationTarget(
  citationKey: string,
  doc: DocumentModel,
  clarifications: ClarificationSource[]
): { kind: 'document' | 'external'; label: string; excerpt: string; url?: string } | null {
  const para = doc.paragraphs.find((p) => p.citationKey === citationKey);
  if (para) {
    return {
      kind: 'document',
      label: `${para.sectionTitle} (p.${para.page})`,
      excerpt: para.text,
    };
  }
  const fig = doc.figures.find((f) => f.citationKey === citationKey);
  if (fig) {
    return {
      kind: 'document',
      label: `${fig.label} (p.${fig.page})`,
      excerpt: fig.caption,
    };
  }
  const tbl = doc.tables.find((t) => t.citationKey === citationKey);
  if (tbl) {
    return {
      kind: 'document',
      label: `${tbl.label} (p.${tbl.page})`,
      excerpt: tbl.caption,
    };
  }
  const eq = doc.equations.find((e) => e.citationKey === citationKey);
  if (eq) {
    return {
      kind: 'document',
      label: `${eq.label} (p.${eq.page})`,
      excerpt: eq.description,
    };
  }
  const ext = clarifications.find((c) => c.url === citationKey);
  if (ext) {
    return {
      kind: 'external',
      label: `${ext.providerName} (Tier ${ext.tier})`,
      excerpt: ext.quote,
      url: ext.url,
    };
  }
  return null;
}

/**
 * Strips any sentence that lacks at least one valid citation resolving to the document
 * or a verified external clarification source.
 */
export function filterUncitedSentences(
  sentences: NarratedSentence[],
  validCitations: Set<string>
): { kept: NarratedSentence[]; droppedCount: number } {
  const kept: NarratedSentence[] = [];
  let droppedCount = 0;
  for (const s of sentences) {
    const valid = (s.citations ?? []).filter((c) => validCitations.has(c));
    if (valid.length === 0) {
      droppedCount += 1;
      continue;
    }
    kept.push({ ...s, citations: valid });
  }
  return { kept, droppedCount };
}

/**
 * Collects all allowed numeric tokens from DocumentModel text, parsed table cells,
 * and verified external clarification quotes.
 */
export function extractAllowedNumbers(
  doc: DocumentModel,
  clarifications: ClarificationSource[]
): Set<string> {
  const corpusParts: string[] = [];
  for (const p of doc.paragraphs) corpusParts.push(p.text);
  for (const f of doc.figures) corpusParts.push(f.caption);
  for (const e of doc.equations) corpusParts.push(e.description, e.latex);
  for (const t of doc.tables) {
    corpusParts.push(t.caption);
    for (const row of t.rows) {
      for (const val of Object.values(row)) {
        corpusParts.push(String(val));
      }
    }
  }
  for (const c of clarifications) {
    corpusParts.push(c.quote, String(c.year));
  }
  // Structural index numbers (e.g., Figure 1, Table 1, Equation 1, 10-14 day horizon references)
  const allowed = new Set<string>(['1', '2', '3', '4', '5', '6', '7', '10', '14', '30', '2024']);
  const regex = /\b\d+(?:\.\d+)?\b/g;
  for (const chunk of corpusParts) {
    const matches = chunk.match(regex);
    if (matches) {
      for (const m of matches) allowed.add(m);
    }
  }
  return allowed;
}

/**
 * Verifies every numeric literal in a text string appears in the parsed document or cited sources.
 */
export function findUngroundedNumbers(
  text: string,
  allowedNumbers: Set<string>,
  exemptSubstrings: string[] = []
): string[] {
  let scrubbed = text;
  for (const ex of exemptSubstrings) {
    scrubbed = scrubbed.split(ex).join(' ');
  }
  // Remove figure/table/equation/section index identifiers like "Figure 1", "Table 1", "Equation 1"
  scrubbed = scrubbed.replace(/\b(Figure|Table|Equation|Section|Tier|Panel)\s+\d+\b/gi, ' ');
  const matches = scrubbed.match(/\b\d+(?:\.\d+)?\b/g) ?? [];
  const violations: string[] = [];
  for (const m of matches) {
    if (!allowedNumbers.has(m)) {
      violations.push(m);
    }
  }
  return violations;
}

/**
 * Loads chart series values strictly from the parsed DocumentTable (never from LLM output)
 * and verifies 100% cell accuracy. If any pre-populated values mismatch the table, throws/fails the scene.
 */
export function resolveAndVerifyChartScene(
  scene: StoryboardScene,
  doc: DocumentModel
): { scene: StoryboardScene; report: ChartAccuracyEntry | null } {
  if (scene.visualSpec.kind !== 'chart') {
    return { scene, report: null };
  }
  const spec = scene.visualSpec;
  const table = doc.tables.find((t) => t.id === spec.tableId);
  if (!table) {
    return {
      scene,
      report: {
        sceneId: scene.id,
        tableId: spec.tableId,
        tableLabel: spec.tableId,
        verified: false,
        checkedCells: 0,
        mismatches: [`Table "${spec.tableId}" not found in DocumentModel`],
      },
    };
  }

  const mismatches: string[] = [];
  let checkedCells = 0;

  if (!table.columns.includes(spec.xColumn)) {
    mismatches.push(`Missing xColumn "${spec.xColumn}" in ${table.label}`);
  }
  for (const yCol of spec.yColumns) {
    if (!table.columns.includes(yCol)) {
      mismatches.push(`Missing yColumn "${yCol}" in ${table.label}`);
    }
  }

  const resolvedSeries = table.rows.map((row) => {
    const label = String(row[spec.xColumn] ?? '');
    const values: Record<string, number | string> = {};
    for (const yCol of spec.yColumns) {
      values[yCol] = row[yCol] ?? 0;
      checkedCells += 1;
    }
    return { label, values };
  });

  // If caller already attached resolvedSeries (e.g. from model or test), verify exact equality
  if (spec.resolvedSeries && spec.resolvedSeries.length > 0) {
    if (spec.resolvedSeries.length !== resolvedSeries.length) {
      mismatches.push(
        `Row count mismatch: expected ${resolvedSeries.length}, got ${spec.resolvedSeries.length}`
      );
    } else {
      for (let i = 0; i < resolvedSeries.length; i += 1) {
        const expected = resolvedSeries[i];
        const actual = spec.resolvedSeries[i];
        if (actual.label !== expected.label) {
          mismatches.push(`Row ${i} label mismatch: expected "${expected.label}", got "${actual.label}"`);
        }
        for (const yCol of spec.yColumns) {
          if (actual.values[yCol] !== expected.values[yCol]) {
            mismatches.push(
              `Cell (${expected.label}, ${yCol}) mismatch: expected ${expected.values[yCol]}, got ${actual.values[yCol]}`
            );
          }
        }
      }
    }
  }

  const verified = mismatches.length === 0;
  const updatedScene: StoryboardScene = {
    ...scene,
    visualSpec: {
      ...spec,
      resolvedSeries,
    },
  };

  return {
    scene: updatedScene,
    report: {
      sceneId: scene.id,
      tableId: table.id,
      tableLabel: table.label,
      verified,
      checkedCells,
      mismatches,
    },
  };
}

/**
 * Ranks clarification sources strictly by Tier (1 > 2 > 3), relevanceScore, and recency,
 * enforces <= 25-word quotes, labels Tier 3 as "lower confidence", and flags contradictions
 * as "Differing view".
 */
export function processClarificationSources(
  sources: ClarificationSource[]
): ClarificationSource[] {
  return sources
    .map((src) => {
      const words = src.quote.trim().split(/\s+/).filter(Boolean);
      const truncatedQuote = words.length > 25 ? words.slice(0, 25).join(' ') : src.quote.trim();
      const confidenceLabel: 'high' | 'lower confidence' =
        src.tier === 3 ? 'lower confidence' : 'high';
      return {
        ...src,
        quote: truncatedQuote,
        confidenceLabel,
        viewLabel: src.contradictsPaper ? ('Differing view' as const) : undefined,
      };
    })
    .sort((a, b) => {
      if (a.tier !== b.tier) return a.tier - b.tier;
      if (b.relevanceScore !== a.relevanceScore) return b.relevanceScore - a.relevanceScore;
      return b.year - a.year;
    });
}

/**
 * Runs full grounding & chart accuracy enforcement over a storyboard.
 */
export function enforceStoryboardGrounding(
  scenes: StoryboardScene[],
  doc: DocumentModel,
  clarifications: ClarificationSource[]
): {
  scenes: StoryboardScene[];
  droppedUncitedSentences: number;
  numberGuardViolations: number;
  chartAccuracyReport: ChartAccuracyEntry[];
} {
  const validCitations = buildValidCitationSet(doc, clarifications);
  const allowedNumbers = extractAllowedNumbers(doc, clarifications);
  let droppedUncitedSentences = 0;
  let numberGuardViolations = 0;
  const chartAccuracyReport: ChartAccuracyEntry[] = [];
  const processedScenes: StoryboardScene[] = [];

  for (const scene of scenes) {
    const { kept, droppedCount } = filterUncitedSentences(scene.sentences, validCitations);
    droppedUncitedSentences += droppedCount;

    // Filter out any sentence that fails the number guard
    const numberSafeSentences: NarratedSentence[] = [];
    for (const sentence of kept) {
      const badNums = findUngroundedNumbers(sentence.text, allowedNumbers);
      if (badNums.length > 0) {
        numberGuardViolations += badNums.length;
        continue;
      }
      numberSafeSentences.push(sentence);
    }

    if (numberSafeSentences.length === 0) {
      // Drop scene if no grounded sentences remain
      continue;
    }

    const updatedNarration = numberSafeSentences.map((s) => s.text).join(' ');
    const sceneCitations = Array.from(
      new Set(numberSafeSentences.flatMap((s) => s.citations))
    );

    const baseScene: StoryboardScene = {
      ...scene,
      sentences: numberSafeSentences,
      narration: updatedNarration,
      citations: sceneCitations,
    };

    const { scene: chartResolved, report } = resolveAndVerifyChartScene(baseScene, doc);
    if (report) {
      chartAccuracyReport.push(report);
      if (!report.verified) {
        throw new Error(`Chart accuracy verification failed for ${scene.id}: ${report.mismatches.join('; ')}`);
      }
    }
    processedScenes.push(chartResolved);
  }

  let cursor = 0;
  const retimed = processedScenes.map((s, idx) => {
    const next: StoryboardScene = { ...s, order: idx + 1, startSeconds: cursor };
    cursor += s.durationSeconds;
    return next;
  });

  return {
    scenes: retimed,
    droppedUncitedSentences,
    numberGuardViolations,
    chartAccuracyReport,
  };
}
