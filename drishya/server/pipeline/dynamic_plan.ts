import {
  ClarificationSource,
  Depth,
  DocumentModel,
  LengthTarget,
  StoryboardScene,
  UnderstandOutput,
} from '../types.ts';
import { processClarificationSources } from './grounding.ts';

function firstSentences(text: string, maxChars = 240): string {
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= maxChars) return clean;
  const split = clean.split(/(?<=[.!?])\s+/);
  let out = split[0] ?? clean.slice(0, maxChars);
  if (split[1] && out.length + split[1].length + 1 <= maxChars) {
    out = `${out} ${split[1]}`;
  }
  if (out.length > maxChars + 40) {
    out = `${out.slice(0, maxChars).replace(/\s+\S*$/, '')}.`;
  }
  return out;
}

function trimToWords(text: string, maxWords: number): string {
  const words = text.replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
  if (words.length <= maxWords) return words.join(' ');
  return words.slice(0, maxWords).join(' ');
}

function extractKeyTopics(doc: DocumentModel): string[] {
  const stop = new Set([
    'about', 'across', 'after', 'among', 'analysis', 'approach', 'based', 'between',
    'paper', 'model', 'models', 'study', 'using', 'method', 'methods', 'results',
    'through', 'their', 'these', 'those', 'under', 'where', 'which', 'while',
    'towards', 'large', 'learning', 'neural', 'network', 'networks', 'research',
  ]);
  const words = `${doc.title} ${doc.paragraphs.slice(0, 2).map((p) => p.text).join(' ')}`
    .replace(/[^A-Za-z0-9\s-]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length >= 5 && !stop.has(w.toLowerCase()));
  const freq = new Map<string, number>();
  for (const w of words) {
    const key = w.toLowerCase();
    freq.set(key, (freq.get(key) ?? 0) + 1);
  }
  return [...freq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([k]) => k);
}

/**
 * Dynamically extracts structured understanding (claims, method steps, results, limitations,
 * glossary, hard parts) directly from any ingested DocumentModel.
 */
export function buildDynamicUnderstandOutput(
  doc: DocumentModel,
  depth: Depth
): UnderstandOutput {
  const paras = doc.paragraphs;
  const pIntro = paras[0];
  const pMid = paras[Math.floor(paras.length / 2)] ?? pIntro;
  const pLate = paras[Math.max(0, paras.length - 2)] ?? pMid;
  const pLast = paras[paras.length - 1] ?? pLate;

  const claims = paras.slice(0, 3).map((p, idx) => ({
    id: `claim-${idx + 1}`,
    statement: firstSentences(p.text, 200),
    citationKey: p.citationKey,
  }));

  const methodSections = doc.sections.slice(0, 3);
  const methodSteps = methodSections.map((sec, idx) => {
    const matchingPara =
      paras.find((p) => p.sectionId === sec.id) ?? paras[Math.min(idx, paras.length - 1)];
    return {
      step: idx + 1,
      title: sec.title.replace(/^\d+\.\s*/, ''),
      summary: matchingPara ? firstSentences(matchingPara.text, 170) : sec.title,
      citationKey: matchingPara ? matchingPara.citationKey : `doc:p${sec.pageStart}/${sec.id}`,
    };
  });

  const tableResults = doc.tables.slice(0, 2).map((tbl) => {
    const numCol = tbl.columns.find((c) => tbl.rows.some((r) => typeof r[c] === 'number')) ?? tbl.columns[1];
    const firstRow = tbl.rows[0];
    return {
      metric: `${tbl.label} (${numCol ?? 'Value'})`,
      value: firstRow && numCol ? `${firstRow[tbl.columns[0]]}: ${firstRow[numCol]}` : tbl.caption,
      citationKey: tbl.citationKey,
    };
  });

  const results =
    tableResults.length > 0
      ? tableResults
      : [
          {
            metric: 'Primary Finding',
            value: pLate ? firstSentences(pLate.text, 160) : doc.title,
            citationKey: pLate ? pLate.citationKey : 'doc:p1/sec-intro',
          },
        ];

  const limitPara =
    paras.find((p) => /limit|challenge|future|gap|constraint|however|caveat/i.test(p.text)) ?? pLast;

  const limitations = [
    {
      statement: limitPara
        ? firstSentences(limitPara.text, 200)
        : 'Scope and evaluation are bounded to the datasets reported in the source paper.',
      citationKey: limitPara ? limitPara.citationKey : pIntro?.citationKey ?? 'doc:p1/sec-intro',
    },
  ];

  const topics = extractKeyTopics(doc);
  const glossary = topics.slice(0, 3).map((topic, idx) => {
    const pMatch = paras.find((p) => p.text.toLowerCase().includes(topic)) ?? paras[idx % paras.length];
    return {
      term: topic.charAt(0).toUpperCase() + topic.slice(1),
      definition: pMatch ? firstSentences(pMatch.text, 160) : `Core concept discussed in ${doc.title}.`,
      citationKey: pMatch ? pMatch.citationKey : 'doc:p1/sec-intro',
    };
  });

  const hardParts = (topics.length > 0 ? topics : ['Core methodology']).slice(0, 3).map((topic, idx) => ({
    id: `hp-dyn-${idx + 1}`,
    term: topic.charAt(0).toUpperCase() + topic.slice(1),
    reason: `Foundational concept in ${doc.title.slice(0, 60)} requiring concise background for ${depth} listeners.`,
    targetDepth: depth,
  }));

  return {
    claims: claims.length > 0 ? claims : [{ id: 'claim-1', statement: doc.title, citationKey: 'doc:p1/sec-intro' }],
    methodSteps:
      methodSteps.length > 0
        ? methodSteps
        : [{ step: 1, title: 'Document Overview', summary: doc.title, citationKey: 'doc:p1/sec-intro' }],
    results,
    limitations,
    glossary,
    hardParts,
  };
}

/**
 * Fetches live Tier 1 (OpenAlex) and Tier 2 (Wikipedia) clarifications for ANY paper's title & hard parts,
 * using only cited paper references + offline-safe fallbacks when offline.
 */
export async function buildDynamicClarifications(
  doc: DocumentModel,
  understand: UnderstandOutput,
  offlineOnly: boolean
): Promise<ClarificationSource[]> {
  const candidates: ClarificationSource[] = [];

  // Always include the paper's own cited references as Tier 1 sources
  for (const ref of doc.references.slice(0, 2)) {
    candidates.push({
      id: `clar-${ref.id}`,
      hardPartId: understand.hardParts[0]?.id ?? 'hp-dyn-1',
      term: doc.title.slice(0, 50),
      tier: 1,
      providerName: ref.arxivId ? 'arXiv Primary Record' : 'Cited Reference',
      title: ref.title,
      url: ref.url,
      year: ref.year,
      relevanceScore: 0.96,
      quote: trimToWords(`Source work by ${ref.authors} published in ${ref.year}: ${ref.title}.`, 24),
      confidenceLabel: 'high',
      contradictsPaper: false,
    });
  }

  if (!offlineOnly) {
    // Tier 1: OpenAlex scholarly search on document title
    try {
      const q = encodeURIComponent(doc.title.slice(0, 90));
      const oaRes = await fetch(`https://api.openalex.org/works?search=${q}&per-page=2`, {
        credentials: 'omit',
        headers: { 'User-Agent': 'DrishyaResearchBot/1.0' },
        signal: AbortSignal.timeout(5000),
      });
      if (oaRes.ok) {
        const oaJson = (await oaRes.json()) as {
          results?: Array<{
            id?: string;
            doi?: string;
            title?: string;
            publication_year?: number;
            cited_by_count?: number;
          }>;
        };
        for (const [idx, work] of (oaJson.results ?? []).entries()) {
          if (!work.title) continue;
          const workUrl = work.doi || work.id;
          if (!workUrl) continue;
          candidates.push({
            id: `clar-oa-${idx + 1}`,
            hardPartId: understand.hardParts[0]?.id ?? 'hp-dyn-1',
            term: understand.hardParts[0]?.term ?? doc.title.slice(0, 40),
            tier: 1,
            providerName: 'OpenAlex Scholarly Index',
            title: work.title,
            url: workUrl,
            year: work.publication_year ?? doc.year,
            relevanceScore: 0.92 - idx * 0.04,
            quote: trimToWords(
              `Scholarly record "${work.title}" (${work.publication_year ?? doc.year}) indexed in OpenAlex with ${work.cited_by_count ?? 0} citations.`,
              24
            ),
            confidenceLabel: 'high',
            contradictsPaper: false,
          });
        }
      }
    } catch {
      // Non-fatal network skip
    }

    // Tier 2: Wikipedia REST summary for the top technical hard part
    const topTerm = understand.hardParts[0]?.term;
    if (topTerm) {
      try {
        const wikiRes = await fetch(
          `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(topTerm)}`,
          {
            credentials: 'omit',
            headers: { 'User-Agent': 'DrishyaResearchBot/1.0' },
            signal: AbortSignal.timeout(4000),
          }
        );
        if (wikiRes.ok) {
          const wiki = (await wikiRes.json()) as {
            title?: string;
            extract?: string;
            content_urls?: { desktop?: { page?: string } };
          };
          if (wiki.extract && wiki.content_urls?.desktop?.page) {
            candidates.push({
              id: 'clar-wiki-1',
              hardPartId: understand.hardParts[0].id,
              term: topTerm,
              tier: 2,
              providerName: 'Wikipedia',
              title: wiki.title || topTerm,
              url: wiki.content_urls.desktop.page,
              year: new Date().getFullYear(),
              relevanceScore: 0.85,
              quote: trimToWords(wiki.extract, 24),
              confidenceLabel: 'high',
              contradictsPaper: false,
            });
          }
        }
      } catch {
        // Non-fatal network skip
      }
    }
  }

  return processClarificationSources(candidates);
}

/**
 * Builds a complete, grounded 6-stage storyboard dynamically from ANY DocumentModel.
 * Every sentence strictly cites valid document/clarification keys and avoids ungrounded numbers.
 */
export function buildDynamicStoryboard(
  doc: DocumentModel,
  understand: UnderstandOutput,
  clarifications: ClarificationSource[],
  depth: Depth,
  lengthTarget: LengthTarget
): StoryboardScene[] {
  const durationScale = lengthTarget === '2min' ? 1.0 : lengthTarget === '5min' ? 2.4 : 4.8;
  const scaleDur = (base: number) => Math.max(10, Math.round(base * durationScale));

  const paras = doc.paragraphs;
  const p0 = paras[0] ?? {
    id: 'p1',
    sectionId: doc.sections[0]?.id ?? 'sec-intro',
    sectionTitle: doc.sections[0]?.title ?? 'Overview',
    page: 1,
    citationKey: 'doc:p1/sec-intro',
    text: doc.title,
  };
  const p1 = paras[1] ?? p0;
  const pMid = paras[Math.floor(paras.length / 2)] ?? p1;
  const pRes = paras[Math.max(0, paras.length - 2)] ?? pMid;
  const pLim =
    paras.find((p) => /limit|challenge|future|gap|constraint|however|caveat/i.test(p.text)) ??
    paras[paras.length - 1] ??
    pRes;

  const scenes: Array<Omit<StoryboardScene, 'startSeconds'>> = [];

  // 1. Why It Matters / Opening Title Card
  const introText = firstSentences(p0.text, 230);
  const openingSentence =
    depth === 'beginner'
      ? `In plain terms, this research examines ${doc.title}. ${introText}`
      : `${doc.title}. ${introText}`;

  scenes.push({
    id: 'scene-1',
    order: 1,
    arcPhase: 'why_it_matters',
    chapterTitle: 'Why This Research Matters',
    narration: openingSentence,
    sentences: [
      {
        id: 's1-1',
        text: openingSentence,
        citations: [p0.citationKey],
        isAnalogy: depth === 'beginner',
      },
    ],
    visualSpec: {
      kind: 'title',
      title: doc.title.slice(0, 72),
      subtitle: `${doc.authors.slice(0, 3).join(', ')} · ${doc.venue}`,
      bullets: understand.claims.slice(0, 3).map((c) => firstSentences(c.statement, 88)),
      isAnalogy: depth === 'beginner',
    },
    citations: [p0.citationKey],
    durationSeconds: scaleDur(20),
  });

  // 2. Background & Clarifications (unless Expert depth)
  if (depth !== 'expert') {
    const topClar = clarifications[0];
    const bgText = topClar
      ? `${firstSentences(p1.text, 190)} Supporting context from ${topClar.providerName} notes: ${topClar.quote}`
      : firstSentences(p1.text, 230);
    const bgCits = topClar ? [p1.citationKey, topClar.url] : [p1.citationKey];

    scenes.push({
      id: 'scene-2',
      order: scenes.length + 1,
      arcPhase: 'background',
      chapterTitle: 'Core Context & Key Concepts',
      narration: bgText,
      sentences: [
        {
          id: 's2-1',
          text: bgText,
          citations: bgCits,
        },
      ],
      visualSpec: {
        kind: 'takeaway',
        title: topClar ? `Background Context (Tier ${topClar.tier})` : 'Key Concepts',
        subtitle: doc.sections[0]?.title || 'Background & Terminology',
        bullets:
          understand.glossary.length > 0
            ? understand.glossary.slice(0, 3).map((g) => `${g.term}: ${firstSentences(g.definition, 75)}`)
            : [firstSentences(p1.text, 95)],
      },
      citations: bgCits,
      durationSeconds: scaleDur(18),
    });
  }

  // 3. Method Diagram from Paper Sections / Method Steps
  const steps = understand.methodSteps.slice(0, 4);
  const methodNodes = (steps.length >= 2 ? steps : [
    { step: 1, title: 'Input & Problem Formulation', summary: p0.text, citationKey: p0.citationKey },
    { step: 2, title: 'Core Architecture & Analysis', summary: pMid.text, citationKey: pMid.citationKey },
    { step: 3, title: 'Evaluation & Outcomes', summary: pRes.text, citationKey: pRes.citationKey },
  ]).map((m, idx) => ({
    id: `dn-${idx + 1}`,
    label: m.title.slice(0, 44),
    group: `Stage ${idx + 1}`,
    step: idx + 1,
  }));

  const methodEdges = methodNodes.slice(0, -1).map((n, idx) => ({
    from: n.id,
    to: methodNodes[idx + 1].id,
    label: 'feeds',
    step: idx + 2,
  }));

  const methodNarration = firstSentences(pMid.text, 240);
  scenes.push({
    id: 'scene-3',
    order: scenes.length + 1,
    arcPhase: 'method',
    chapterTitle: 'Methodology & Workflow',
    narration: methodNarration,
    sentences: [
      {
        id: 's3-1',
        text: methodNarration,
        citations: [pMid.citationKey],
      },
    ],
    visualSpec: {
      kind: 'diagram',
      title: 'Paper Methodology Pipeline',
      nodes: methodNodes,
      edges: methodEdges,
    },
    citations: [pMid.citationKey],
    durationSeconds: scaleDur(22),
  });

  // 4. Real Extracted Figure Walkthrough (only if document has real figures)
  const fig1 = doc.figures[0];
  if (fig1) {
    const figText = firstSentences(fig1.caption, 220);
    scenes.push({
      id: 'scene-4',
      order: scenes.length + 1,
      arcPhase: 'method',
      chapterTitle: `${fig1.label} Walkthrough`,
      narration: figText,
      sentences: [
        {
          id: 's4-1',
          text: figText,
          citations: [fig1.citationKey, pMid.citationKey],
        },
      ],
      visualSpec: {
        kind: 'figure',
        title: fig1.label,
        figureId: fig1.id,
        caption: fig1.caption,
        highlightBoxes: [
          { xPct: 8, yPct: 14, wPct: 84, hPct: 72, label: fig1.label, step: 1 },
        ],
      },
      citations: [fig1.citationKey, pMid.citationKey],
      durationSeconds: scaleDur(18),
    });
  }

  // 5. Real Extracted Equation Walkthrough (only if document has real equations)
  const eq1 = doc.equations[0];
  if (eq1) {
    const eqText = firstSentences(eq1.description, 200);
    scenes.push({
      id: 'scene-5',
      order: scenes.length + 1,
      arcPhase: 'method',
      chapterTitle: `${eq1.label} Breakdown`,
      narration: eqText,
      sentences: [
        {
          id: 's5-1',
          text: eqText,
          citations: [eq1.citationKey],
        },
      ],
      visualSpec: {
        kind: 'equation',
        title: eq1.label,
        equationId: eq1.id,
        latex: eq1.latex,
        terms: [
          { symbolLatex: eq1.latex.slice(0, 32), meaning: eq1.description, step: 1 },
        ],
      },
      citations: [eq1.citationKey],
      durationSeconds: scaleDur(18),
    });
  }

  // 6. Quantitative Results (Verified Chart from Parsed Table if present, else Findings Card)
  const table1 = doc.tables[0];
  const numericCols = table1
    ? table1.columns.slice(1).filter((col) => table1.rows.some((r) => typeof r[col] === 'number'))
    : [];
  if (table1 && numericCols.length >= 1) {
    const xCol = table1.columns[0];
    const yCols = numericCols.slice(0, 2);
    const resText = `${table1.caption} ${firstSentences(pRes.text, 160)}`.trim();
    scenes.push({
      id: 'scene-6',
      order: scenes.length + 1,
      arcPhase: 'results',
      chapterTitle: `Results (${table1.label})`,
      narration: resText,
      sentences: [
        {
          id: 's6-1',
          text: resText,
          citations: [table1.citationKey, pRes.citationKey],
        },
      ],
      visualSpec: {
        kind: 'chart',
        title: table1.caption.slice(0, 72),
        chartType: 'grouped-bar',
        tableId: table1.id,
        xColumn: xCol,
        yColumns: yCols,
        highlightRow: String(table1.rows[table1.rows.length - 1]?.[xCol] ?? ''),
      },
      citations: [table1.citationKey, pRes.citationKey],
      durationSeconds: scaleDur(22),
    });
  } else {
    const resText = firstSentences(pRes.text, 240);
    scenes.push({
      id: 'scene-6',
      order: scenes.length + 1,
      arcPhase: 'results',
      chapterTitle: 'Key Results & Evidence',
      narration: resText,
      sentences: [
        {
          id: 's6-1',
          text: resText,
          citations: [pRes.citationKey],
        },
      ],
      visualSpec: {
        kind: 'takeaway',
        title: 'Extracted Key Findings',
        subtitle: pRes.sectionTitle,
        bullets: paras
          .slice(Math.max(0, paras.length - 3))
          .map((p) => firstSentences(p.text, 92)),
      },
      citations: [pRes.citationKey],
      durationSeconds: scaleDur(20),
    });
  }

  // 7. Limitations & What's Next
  const limText = firstSentences(pLim.text, 220);
  scenes.push({
    id: 'scene-7',
    order: scenes.length + 1,
    arcPhase: 'limitations',
    chapterTitle: 'Limitations & Takeaways',
    narration: limText,
    sentences: [
      {
        id: 's7-1',
        text: limText,
        citations: [pLim.citationKey],
      },
    ],
    visualSpec: {
      kind: 'takeaway',
      title: 'Limitations & Future Directions',
      subtitle: doc.title.slice(0, 64),
      bullets: [
        firstSentences(pLim.text, 92),
        `Source citation: ${pLim.citationKey}`,
        'Ask follow-up questions in the Grounded Q&A panel',
      ],
    },
    citations: [pLim.citationKey],
    durationSeconds: scaleDur(18),
  });

  let cursor = 0;
  return scenes.map((s) => {
    const out: StoryboardScene = { ...s, startSeconds: cursor };
    cursor += s.durationSeconds;
    return out;
  });
}
