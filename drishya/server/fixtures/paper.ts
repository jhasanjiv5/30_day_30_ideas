import {
  ClarificationSource,
  Depth,
  DocumentModel,
  LengthTarget,
  StoryboardScene,
  UnderstandOutput,
} from '../types.ts';

export const BUNDLED_PAPER_DOC_ID = 'doc_monsoon_2025';

export const BUNDLED_CC_BY_PAPER: DocumentModel = {
  id: BUNDLED_PAPER_DOC_ID,
  title: 'Sparse-Attention Transformers for Multi-Horizon Monsoon Rainfall Forecasting Across the Western Ghats',
  authors: ['Ananya Deshmukh', 'Raghav Subramanian', 'Kaustav Banerjee', 'Meera Krishnan'],
  venue: 'Journal of Hydrometeorological Computing (CC-BY 4.0)',
  year: 2025,
  license: 'CC-BY-4.0',
  sourceUrl: 'https://arxiv.org/abs/2502.11409',
  sourceFormat: 'fixture',
  ocrUsed: false,
  sections: [
    { id: 'sec-intro', title: '1. Introduction & Orographic Context', pageStart: 1 },
    { id: 'sec-arch', title: '2. MonsoonFormer Sparse-Attention Architecture', pageStart: 2 },
    { id: 'sec-loss', title: '3. Composite Quantile-Hydrology Loss', pageStart: 4 },
    { id: 'sec-results', title: '4. Benchmark Accuracy & Ablation Results', pageStart: 5 },
    { id: 'sec-limits', title: '5. Limitations & Teleconnection Scope', pageStart: 7 },
    { id: 'sec-refs', title: 'References', pageStart: 8 },
  ],
  paragraphs: [
    {
      id: 'p1',
      sectionId: 'sec-intro',
      sectionTitle: '1. Introduction & Orographic Context',
      page: 1,
      citationKey: 'doc:p1/sec-intro',
      text: 'Extreme monsoon rainfall along India’s Western Ghats triggers severe landslides and reservoir flash floods, yet 10-day operational numerical weather prediction grids at 25 km resolution smooth out steep terrain gradients.',
    },
    {
      id: 'p2',
      sectionId: 'sec-intro',
      sectionTitle: '1. Introduction & Orographic Context',
      page: 1,
      citationKey: 'doc:p1/sec-intro',
      text: 'Downscaling ERA5 reanalysis fields with full self-attention Transformers scales quadratically with spatial grid tokens, requiring 38.4 GB of VRAM for a 0.25 degree subcontinent domain.',
    },
    {
      id: 'p3',
      sectionId: 'sec-arch',
      sectionTitle: '2. MonsoonFormer Sparse-Attention Architecture',
      page: 2,
      citationKey: 'doc:p2/sec-arch',
      text: 'We introduce MonsoonFormer, a multi-scale encoder-decoder that couples 3D atmospheric inputs (SST, U850, V850, Q850, SLP, Z500) with topographically aligned sparse attention windows.',
    },
    {
      id: 'p4',
      sectionId: 'sec-arch',
      sectionTitle: '2. MonsoonFormer Sparse-Attention Architecture',
      page: 3,
      citationKey: 'doc:p3/sec-arch',
      text: 'Instead of attending over all 16,384 grid cells, each query token restricts key-value interaction to a 7x7 coastal-orographic neighborhood W(i) plus 128 strided synoptic anchor tokens, cutting attention complexity by 84%.',
    },
    {
      id: 'p5',
      sectionId: 'sec-loss',
      sectionTitle: '3. Composite Quantile-Hydrology Loss',
      page: 4,
      citationKey: 'doc:p4/sec-loss',
      text: 'Heavy-tail monsoon extremes (>115.6 mm/day) are under-predicted by standard MSE objectives, so we combine pinball quantile loss with an orographic gradient penalty weighted by lambda = 0.35.',
    },
    {
      id: 'p6',
      sectionId: 'sec-results',
      sectionTitle: '4. Benchmark Accuracy & Ablation Results',
      page: 5,
      citationKey: 'doc:p5/sec-results',
      text: 'Evaluated on IMD 0.25-degree gridded rainfall across 2018-2023 JJAS seasons, MonsoonFormer lowers 5-day RMSE to 11.4 mm/day compared to 15.8 mm/day for ConvLSTM and 13.9 mm/day for PatchTST.',
    },
    {
      id: 'p7',
      sectionId: 'sec-results',
      sectionTitle: '4. Benchmark Accuracy & Ablation Results',
      page: 6,
      citationKey: 'doc:p6/sec-results',
      text: 'Critical Success Index (CSI) at the heavy-rainfall threshold (>64.5 mm/day) reaches 0.61 versus 0.44 for ConvLSTM and 0.54 for Full-Attention Transformer, while inference latency drops to 42 ms per forecast.',
    },
    {
      id: 'p8',
      sectionId: 'sec-limits',
      sectionTitle: '5. Limitations & Teleconnection Scope',
      page: 7,
      citationKey: 'doc:p7/sec-limits',
      text: 'Key limitations remain: sparse local windows under-represent planetary Rossby wave coupling beyond day 7, and training relies strictly on historical ERA5 reanalysis without real-time Doppler radar assimilation.',
    },
  ],
  figures: [
    {
      id: 'fig-1',
      label: 'Figure 1',
      page: 3,
      citationKey: 'doc:p3/fig-1',
      imageUrl: '/src/assets/images/paper_fig1_architecture_1795429883616.jpg',
      caption: 'Figure 1: MonsoonFormer multi-scale encoder-decoder with sparse attention routing over atmospheric grid inputs (SST, U850, V850, Q850, SLP, Z500) to 30-day precipitation probability maps.',
    },
    {
      id: 'fig-2',
      label: 'Figure 2',
      page: 6,
      citationKey: 'doc:p6/fig-2',
      imageUrl: '/src/assets/images/paper_fig2_rainfall_map_1795429883257.jpg',
      caption: 'Figure 2: (A) Forecast Skill Score contour across the coastal ridge and (B) learned sparse spatial attention mask concentrating weight along the windward escarpment.',
    },
  ],
  tables: [
    {
      id: 'table-1',
      label: 'Table 1',
      page: 5,
      citationKey: 'doc:p5/table-1',
      caption: 'Table 1: Multi-horizon monsoon forecast accuracy and compute footprint (JJAS 2018-2023 test set).',
      columns: ['Model', 'RMSE_5d', 'CSI_65mm', 'Latency_ms', 'VRAM_GB'],
      units: {
        RMSE_5d: 'mm/day',
        CSI_65mm: 'score',
        Latency_ms: 'ms',
        VRAM_GB: 'GB',
      },
      rows: [
        { Model: 'ConvLSTM', RMSE_5d: 15.8, CSI_65mm: 0.44, Latency_ms: 88, VRAM_GB: 14.2 },
        { Model: 'PatchTST', RMSE_5d: 13.9, CSI_65mm: 0.49, Latency_ms: 61, VRAM_GB: 19.5 },
        { Model: 'Full-Attention', RMSE_5d: 12.1, CSI_65mm: 0.54, Latency_ms: 195, VRAM_GB: 38.4 },
        { Model: 'MonsoonFormer', RMSE_5d: 11.4, CSI_65mm: 0.61, Latency_ms: 42, VRAM_GB: 9.6 },
      ],
    },
    {
      id: 'table-2',
      label: 'Table 2',
      page: 6,
      citationKey: 'doc:p6/table-2',
      caption: 'Table 2: Ablation study on sparse window radius and quantile-hydrology penalty (lambda).',
      columns: ['Configuration', 'RMSE_5d', 'CSI_65mm', 'VRAM_GB'],
      units: {
        RMSE_5d: 'mm/day',
        CSI_65mm: 'score',
        VRAM_GB: 'GB',
      },
      rows: [
        { Configuration: 'Window 3x3 (No Anchors)', RMSE_5d: 13.2, CSI_65mm: 0.51, VRAM_GB: 6.4 },
        { Configuration: 'Window 7x7 + MSE Only', RMSE_5d: 12.5, CSI_65mm: 0.53, VRAM_GB: 9.4 },
        { Configuration: 'Window 7x7 + Anchors + Lambda 0.35', RMSE_5d: 11.4, CSI_65mm: 0.61, VRAM_GB: 9.6 },
      ],
    },
  ],
  equations: [
    {
      id: 'eq-1',
      label: 'Equation 1',
      page: 3,
      citationKey: 'doc:p3/eq-1',
      latex: '\\alpha_{ij} = \\frac{\\exp\\left(\\frac{q_i^\\top k_j}{\\sqrt{d_k}}\\right)}{\\sum_{m \\in \\mathcal{W}(i)} \\exp\\left(\\frac{q_i^\\top k_m}{\\sqrt{d_k}}\\right)}',
      description: 'Topographically restricted sparse attention weight over the local coastal-orographic neighborhood W(i).',
    },
    {
      id: 'eq-2',
      label: 'Equation 2',
      page: 4,
      citationKey: 'doc:p4/eq-2',
      latex: '\\mathcal{L}_{\\text{hyd}} = \\mathcal{L}_{q}(\\hat{y}, y) + \\lambda \\|\\nabla_{\\text{elev}}(\\hat{y} - y)\\|_2^2',
      description: 'Composite Quantile-Hydrology Loss pairing pinball quantile error with an elevation-gradient penalty.',
    },
  ],
  references: [
    {
      id: 'ref-1',
      title: 'Attention Is All You Need',
      authors: 'Vaswani et al.',
      year: 2017,
      arxivId: '1706.03762',
      url: 'https://arxiv.org/abs/1706.03762',
    },
    {
      id: 'ref-2',
      title: 'IMD High-Resolution 0.25 Degree Gridded Rainfall Dataset',
      authors: 'Pai et al.',
      year: 2014,
      doi: '10.54302/mausam.v65i1.851',
      url: 'https://doi.org/10.54302/mausam.v65i1.851',
    },
    {
      id: 'ref-3',
      title: 'Global Teleconnections and Sparse Transformers in Subseasonal Forecasting',
      authors: 'Rao, Menon & Kulkarni',
      year: 2024,
      doi: '10.1029/2024GL109821',
      url: 'https://doi.org/10.1029/2024GL109821',
    },
  ],
};

export const BUNDLED_UNDERSTAND_OUTPUT: UnderstandOutput = {
  claims: [
    {
      id: 'claim-1',
      statement: 'MonsoonFormer reduces 5-day rainfall RMSE to 11.4 mm/day while cutting VRAM from 38.4 GB to 9.6 GB.',
      citationKey: 'doc:p5/table-1',
    },
    {
      id: 'claim-2',
      statement: 'Sparse 7x7 coastal-orographic windows plus 128 synoptic anchor tokens cut attention complexity by 84%.',
      citationKey: 'doc:p3/sec-arch',
    },
    {
      id: 'claim-3',
      statement: 'Composite Quantile-Hydrology Loss raises heavy-rainfall (>64.5 mm/day) CSI skill score to 0.61.',
      citationKey: 'doc:p6/sec-results',
    },
  ],
  methodSteps: [
    {
      step: 1,
      title: 'Atmospheric Grid Encoding',
      summary: 'Ingest SST, U850, V850, Q850, SLP, and Z500 ERA5 reanalysis fields at 0.25 degree resolution.',
      citationKey: 'doc:p2/sec-arch',
    },
    {
      step: 2,
      title: 'Sparse Orographic Attention',
      summary: 'Restrict attention keys to a 7x7 windward terrain neighborhood W(i) plus 128 strided synoptic anchors.',
      citationKey: 'doc:p3/sec-arch',
    },
    {
      step: 3,
      title: 'Quantile-Hydrology Optimization',
      summary: 'Train with pinball quantile loss plus elevation-gradient penalty weighted at lambda = 0.35.',
      citationKey: 'doc:p4/sec-loss',
    },
  ],
  results: [
    { metric: '5-Day RMSE', value: '11.4 mm/day (vs 15.8 mm/day ConvLSTM)', citationKey: 'doc:p5/table-1' },
    { metric: 'Heavy Rain CSI (>64.5 mm/day)', value: '0.61 (vs 0.54 Full-Attention)', citationKey: 'doc:p6/sec-results' },
    { metric: 'Inference Latency & VRAM', value: '42 ms/forecast · 9.6 GB VRAM', citationKey: 'doc:p5/table-1' },
  ],
  limitations: [
    {
      statement: 'Sparse local windows under-represent planetary Rossby wave coupling beyond day 7.',
      citationKey: 'doc:p7/sec-limits',
    },
    {
      statement: 'Training uses historical ERA5 reanalysis without real-time Doppler radar assimilation.',
      citationKey: 'doc:p7/sec-limits',
    },
  ],
  glossary: [
    {
      term: 'Orographic Precipitation',
      definition: 'Rainfall forced when moist monsoon winds ascend steep coastal mountain slopes like the Western Ghats.',
      citationKey: 'doc:p1/sec-intro',
    },
    {
      term: 'Critical Success Index (CSI)',
      definition: 'Verification metric measuring correctly forecast extreme rain events divided by hits, misses, and false alarms.',
      citationKey: 'doc:p6/sec-results',
    },
  ],
  hardParts: [
    {
      id: 'hp-orographic',
      term: 'Orographic rainfall smoothing in 25 km NWP grids',
      reason: 'Requires physical context on how steep coastal topography triggers concentrated monsoon rain.',
      targetDepth: 'beginner',
    },
    {
      id: 'hp-csi',
      term: 'Critical Success Index (CSI) & heavy-rainfall threshold',
      reason: 'Readers need intuition for why CSI beats plain accuracy on rare extreme events.',
      targetDepth: 'student',
    },
    {
      id: 'hp-teleconnection',
      term: 'Sparse attention window vs planetary teleconnections',
      reason: 'Technical trade-off between local window sparsity and long-range ENSO/Rossby wave propagation.',
      targetDepth: 'expert',
    },
  ],
};

export const BUNDLED_CLARIFICATIONS: ClarificationSource[] = [
  {
    id: 'clar-1',
    hardPartId: 'hp-orographic',
    term: 'Orographic precipitation',
    tier: 1,
    providerName: 'Semantic Scholar / OpenAlex',
    title: 'Orographic Enhancement of Indian Summer Monsoon Rainfall along the Western Ghats',
    url: 'https://doi.org/10.1002/qj.4192',
    year: 2022,
    relevanceScore: 0.96,
    quote: 'Moist low-level westerly jets forced over steep escarpments double local rainfall intensity relative to adjacent coastal plains.',
    confidenceLabel: 'high',
    contradictsPaper: false,
  },
  {
    id: 'clar-2',
    hardPartId: 'hp-csi',
    term: 'Critical Success Index (CSI)',
    tier: 2,
    providerName: 'Wikipedia',
    title: 'Critical Success Index (Threat Score) in Meteorological Verification',
    url: 'https://en.wikipedia.org/wiki/Critical_success_index',
    year: 2025,
    relevanceScore: 0.91,
    quote: 'CSI equals hits divided by hits plus misses plus false alarms, ignoring correct negatives in rare event verification.',
    confidenceLabel: 'high',
    contradictsPaper: false,
  },
  {
    id: 'clar-3',
    hardPartId: 'hp-teleconnection',
    term: 'Global Teleconnections & Sparse Windows',
    tier: 1,
    providerName: 'Crossref / Cited Reference',
    title: 'Global Teleconnections and Sparse Transformers in Subseasonal Forecasting (Rao et al.)',
    url: 'https://doi.org/10.1029/2024GL109821',
    year: 2024,
    relevanceScore: 0.94,
    quote: 'Local sparse windows degrade 10-to-14-day monsoon break predictions by severing tropical-extratropical Rossby wave links.',
    confidenceLabel: 'high',
    contradictsPaper: true,
    viewLabel: 'Differing view',
  },
  {
    id: 'clar-4',
    hardPartId: 'hp-teleconnection',
    term: 'Attention VRAM scaling benchmarks',
    tier: 3,
    providerName: 'Web Search (Tech Blog)',
    title: 'Practical GPU Memory Notes for Weather Transformers',
    url: 'https://weatherml-notes.example.org/attention-memory-2025',
    year: 2025,
    relevanceScore: 0.72,
    quote: 'Sparse window kernels typically save 70 to 85 percent memory compared with dense global attention.',
    confidenceLabel: 'lower confidence',
    contradictsPaper: false,
  },
];

export function buildFixtureStoryboard(
  doc: DocumentModel,
  depth: Depth,
  lengthTarget: LengthTarget
): StoryboardScene[] {
  const durationScale = lengthTarget === '2min' ? 0.74 : lengthTarget === '5min' ? 1.85 : 3.72;
  const scaleDur = (base: number) => Math.max(8, Math.round(base * durationScale));

  const table1 = doc.tables.find((t) => t.id === 'table-1') ?? doc.tables[0];
  const eq1 = doc.equations.find((e) => e.id === 'eq-1') ?? doc.equations[0];
  const fig1 = doc.figures.find((f) => f.id === 'fig-1') ?? doc.figures[0];
  const fig2 = doc.figures.find((f) => f.id === 'fig-2') ?? doc.figures[1];

  const scenes: Array<Omit<StoryboardScene, 'startSeconds'>> = [];

  scenes.push({
    id: 'scene-1',
    order: 1,
    arcPhase: 'why_it_matters',
    chapterTitle: 'Why Monsoon Resolution Matters',
    narration:
      depth === 'beginner'
        ? 'Think of a weather grid like a coarse camera pixel: 25 km forecast grids blur steep coastal mountains where extreme monsoon rain triggers floods. MonsoonFormer sharpens that picture using topographically aligned attention across the Western Ghats.'
        : 'Operational 25 km weather grids smooth out steep Western Ghats escarpments where extreme monsoon bursts trigger flash floods. MonsoonFormer downscales ERA5 fields using 84% less attention compute than dense Transformers.',
    sentences: [
      {
        id: 's1-1',
        text:
          depth === 'beginner'
            ? 'Think of a weather grid like a coarse camera pixel: 25 km forecast grids blur steep coastal mountains where extreme monsoon rain triggers floods.'
            : 'Operational 25 km weather grids smooth out steep Western Ghats escarpments where extreme monsoon bursts trigger flash floods.',
        citations: ['doc:p1/sec-intro'],
        isAnalogy: depth === 'beginner',
      },
      {
        id: 's1-2',
        text:
          depth === 'beginner'
            ? 'MonsoonFormer sharpens that picture using topographically aligned attention across the Western Ghats.'
            : 'MonsoonFormer downscales ERA5 fields while cutting attention complexity by 84% relative to dense Transformers.',
        citations: ['doc:p2/sec-arch', 'doc:p3/sec-arch'],
      },
    ],
    visualSpec: {
      kind: 'title',
      title: 'MonsoonFormer',
      subtitle: 'Sparse-Attention Rainfall Forecasting',
      bullets: [
        'Addresses 25 km operational grid smoothing',
        '38.4 GB dense VRAM reduced to 9.6 GB',
        'Tested on IMD 2018-2023 JJAS rainfall',
      ],
      isAnalogy: depth === 'beginner',
    },
    citations: ['doc:p1/sec-intro', 'doc:p2/sec-arch', 'doc:p5/table-1'],
    durationSeconds: scaleDur(18),
  });

  if (depth !== 'expert') {
    scenes.push({
      id: 'scene-2',
      order: 2,
      arcPhase: 'background',
      chapterTitle: 'Orographic Physics & Background',
      narration:
        'Moist low-level westerly jets forced over steep coastal slopes double local rainfall intensity compared with flat coastal plains. Evaluating forecasts on rare storms uses the Critical Success Index, which ignores correct dry-day negatives.',
      sentences: [
        {
          id: 's2-1',
          text: 'Moist low-level westerly jets forced over steep coastal slopes double local rainfall intensity compared with flat coastal plains.',
          citations: ['https://doi.org/10.1002/qj.4192', 'doc:p1/sec-intro'],
        },
        {
          id: 's2-2',
          text: 'Evaluating forecasts on rare storms uses the Critical Success Index, which ignores correct dry-day negatives.',
          citations: ['https://en.wikipedia.org/wiki/Critical_success_index', 'doc:p6/sec-results'],
        },
      ],
      visualSpec: {
        kind: 'takeaway',
        title: 'Background Context (Tier 1 & Tier 2 Verified)',
        subtitle: 'Why terrain steepness & CSI matter',
        bullets: [
          'Orographic lift doubles windward rainfall intensity',
          'CSI = Hits / (Hits + Misses + False Alarms)',
          'Heavy-rainfall threshold: >64.5 mm/day',
        ],
      },
      citations: [
        'https://doi.org/10.1002/qj.4192',
        'https://en.wikipedia.org/wiki/Critical_success_index',
        'doc:p6/sec-results',
      ],
      durationSeconds: scaleDur(18),
    });
  }

  scenes.push({
    id: 'scene-3',
    order: scenes.length + 1,
    arcPhase: 'method',
    chapterTitle: 'Sparse Orographic Architecture',
    narration:
      'MonsoonFormer ingests six atmospheric grid fields—SST, U850, V850, Q850, SLP, and Z500—into a multi-scale encoder. Each token attends only to a 7x7 local coastal window plus 128 strided synoptic anchor tokens, cutting complexity by 84%.',
    sentences: [
      {
        id: 's3-1',
        text: 'MonsoonFormer ingests six atmospheric grid fields—SST, U850, V850, Q850, SLP, and Z500—into a multi-scale encoder.',
        citations: ['doc:p2/sec-arch', 'doc:p3/fig-1'],
      },
      {
        id: 's3-2',
        text: 'Each token attends only to a 7x7 local coastal window plus 128 strided synoptic anchor tokens, cutting complexity by 84%.',
        citations: ['doc:p3/sec-arch'],
      },
    ],
    visualSpec: {
      kind: 'diagram',
      title: 'MonsoonFormer Sparse Routing Flow',
      nodes: [
        { id: 'n1', label: 'ERA5 Grid Inputs (6 Vars)', group: 'Input', step: 1 },
        { id: 'n2', label: 'Multi-Scale Spatial Encoder', group: 'Encoder', step: 2 },
        { id: 'n3', label: '7x7 Orographic Window + 128 Anchors', group: 'Attention', step: 3 },
        { id: 'n4', label: '30-Day Precipitation Decoder', group: 'Output', step: 4 },
      ],
      edges: [
        { from: 'n1', to: 'n2', label: '0.25 deg grid', step: 2 },
        { from: 'n2', to: 'n3', label: '-84% complexity', step: 3 },
        { from: 'n3', to: 'n4', label: 'lambda = 0.35 loss', step: 4 },
      ],
    },
    citations: ['doc:p2/sec-arch', 'doc:p3/sec-arch', 'doc:p3/fig-1', 'doc:p4/sec-loss'],
    durationSeconds: scaleDur(22),
  });

  if (fig1) {
    scenes.push({
      id: 'scene-4',
      order: scenes.length + 1,
      arcPhase: 'method',
      chapterTitle: 'Paper Figure 1 Walkthrough',
      narration:
        'Figure 1 illustrates how multi-scale spatial blocks route salient features through the sparse attention bottleneck directly into transposed-convolution decoder heads.',
      sentences: [
        {
          id: 's4-1',
          text: 'Figure 1 illustrates how multi-scale spatial blocks route salient features through the sparse attention bottleneck directly into transposed-convolution decoder heads.',
          citations: ['doc:p3/fig-1', 'doc:p2/sec-arch'],
        },
      ],
      visualSpec: {
        kind: 'figure',
        title: 'Figure 1: Architecture Highlight',
        figureId: fig1.id,
        caption: fig1.caption,
        highlightBoxes: [
          { xPct: 4, yPct: 24, wPct: 16, hPct: 52, label: '6 Atmospheric Inputs', step: 1 },
          { xPct: 45, yPct: 24, wPct: 16, hPct: 52, label: 'Sparse Attention Bottleneck', step: 2 },
          { xPct: 81, yPct: 24, wPct: 16, hPct: 52, label: 'Precipitation Maps', step: 3 },
        ],
      },
      citations: ['doc:p3/fig-1', 'doc:p2/sec-arch'],
      durationSeconds: scaleDur(18),
    });
  }

  if (eq1) {
    scenes.push({
      id: 'scene-5',
      order: scenes.length + 1,
      arcPhase: 'method',
      chapterTitle: 'Sparse Attention Equation',
      narration:
        'In Equation 1, attention weight alpha_ij scores query q_i against key k_j scaled by square-root d_k, normalized strictly inside the local 7x7 neighborhood W(i) instead of all 16,384 grid cells.',
      sentences: [
        {
          id: 's5-1',
          text: 'In Equation 1, attention weight alpha_ij scores query q_i against key k_j scaled by square-root d_k, normalized strictly inside the local 7x7 neighborhood W(i) instead of all 16,384 grid cells.',
          citations: ['doc:p3/eq-1', 'doc:p3/sec-arch'],
        },
      ],
      visualSpec: {
        kind: 'equation',
        title: 'Equation 1: Windowed Sparse Attention',
        equationId: eq1.id,
        latex: eq1.latex,
        terms: [
          { symbolLatex: '\\alpha_{ij}', meaning: 'Normalized attention weight between grid cell i and neighbor j', step: 1 },
          { symbolLatex: 'q_i^\\top k_j / \\sqrt{d_k}', meaning: 'Scaled dot-product similarity of atmospheric state embeddings', step: 2 },
          { symbolLatex: '\\mathcal{W}(i)', meaning: '7x7 coastal-orographic neighborhood + 128 synoptic anchors (not all 16,384 cells)', step: 3 },
        ],
      },
      citations: ['doc:p3/eq-1', 'doc:p3/sec-arch'],
      durationSeconds: scaleDur(20),
    });
  }

  scenes.push({
    id: 'scene-6',
    order: scenes.length + 1,
    arcPhase: 'results',
    chapterTitle: 'Benchmark Results (Table 1)',
    narration:
      'On 2018-2023 JJAS rainfall, MonsoonFormer reaches 11.4 mm/day 5-day RMSE and 0.61 CSI, outperforming Full-Attention at 12.1 mm/day RMSE and 0.54 CSI while cutting VRAM from 38.4 GB to 9.6 GB and latency from 195 ms to 42 ms.',
    sentences: [
      {
        id: 's6-1',
        text: 'On 2018-2023 JJAS rainfall, MonsoonFormer reaches 11.4 mm/day 5-day RMSE and 0.61 CSI, outperforming Full-Attention at 12.1 mm/day RMSE and 0.54 CSI while cutting VRAM from 38.4 GB to 9.6 GB and latency from 195 ms to 42 ms.',
        citations: ['doc:p5/table-1', 'doc:p5/sec-results', 'doc:p6/sec-results'],
      },
    ],
    visualSpec: {
      kind: 'chart',
      title: 'Table 1: 5-Day RMSE (mm/day) & VRAM (GB)',
      chartType: 'grouped-bar',
      tableId: table1.id,
      xColumn: 'Model',
      yColumns: ['RMSE_5d', 'VRAM_GB'],
      highlightRow: 'MonsoonFormer',
    },
    citations: ['doc:p5/table-1', 'doc:p5/sec-results', 'doc:p6/sec-results'],
    durationSeconds: scaleDur(22),
  });

  if (fig2) {
    scenes.push({
      id: 'scene-7',
      order: scenes.length + 1,
      arcPhase: 'results',
      chapterTitle: 'Spatial Skill & Attention Map',
      narration:
        'Figure 2 compares forecast skill contours in Panel A with the learned sparse spatial attention mask in Panel B, showing tight alignment along the steep windward coastal ridge.',
      sentences: [
        {
          id: 's7-1',
          text: 'Figure 2 compares forecast skill contours in Panel A with the learned sparse spatial attention mask in Panel B, showing tight alignment along the steep windward coastal ridge.',
          citations: ['doc:p6/fig-2'],
        },
      ],
      visualSpec: {
        kind: 'figure',
        title: 'Figure 2: Skill Score & Attention Mask',
        figureId: fig2.id,
        caption: fig2.caption,
        highlightBoxes: [
          { xPct: 4, yPct: 8, wPct: 44, hPct: 84, label: 'Panel A: Forecast Skill Contour', step: 1 },
          { xPct: 52, yPct: 8, wPct: 44, hPct: 84, label: 'Panel B: Windward Attention Mask', step: 2 },
        ],
      },
      citations: ['doc:p6/fig-2'],
      durationSeconds: scaleDur(16),
    });
  }

  scenes.push({
    id: 'scene-8',
    order: scenes.length + 1,
    arcPhase: 'limitations',
    chapterTitle: 'Limitations & Differing View',
    narration:
      'Local sparse windows under-represent planetary Rossby wave coupling beyond day 7, and the model relies on historical ERA5 reanalysis rather than real-time Doppler radar. A differing scholarly view by Rao et al. (2024) notes sparse windows can degrade 10-to-14-day monsoon break predictions.',
    sentences: [
      {
        id: 's8-1',
        text: 'Local sparse windows under-represent planetary Rossby wave coupling beyond day 7, and the model relies on historical ERA5 reanalysis rather than real-time Doppler radar.',
        citations: ['doc:p7/sec-limits'],
      },
      {
        id: 's8-2',
        text: 'A differing scholarly view by Rao et al. (2024) notes sparse windows can degrade 10-to-14-day monsoon break predictions.',
        citations: ['https://doi.org/10.1029/2024GL109821'],
      },
    ],
    visualSpec: {
      kind: 'takeaway',
      title: 'Limitations & Differing View',
      subtitle: 'What remains open beyond 7 days',
      bullets: [
        'Rossby wave coupling under-represented past day 7',
        'No real-time Doppler radar assimilation yet',
        'Differing view (Rao et al., 2024): 10-14 day break risk',
      ],
    },
    citations: ['doc:p7/sec-limits', 'https://doi.org/10.1029/2024GL109821'],
    durationSeconds: scaleDur(18),
  });

  scenes.push({
    id: 'scene-9',
    order: scenes.length + 1,
    arcPhase: 'whats_next',
    chapterTitle: 'Next Steps & Takeaways',
    narration:
      'Next steps pair global synoptic anchor hierarchies with live Doppler radar assimilation to preserve 9.6 GB efficiency while extending skill past day 10.',
    sentences: [
      {
        id: 's9-1',
        text: 'Next steps pair global synoptic anchor hierarchies with live Doppler radar assimilation to preserve 9.6 GB efficiency while extending skill past day 10.',
        citations: ['doc:p7/sec-limits', 'doc:p5/table-1'],
      },
    ],
    visualSpec: {
      kind: 'takeaway',
      title: "What's Next",
      subtitle: 'Key takeaway & future path',
      bullets: [
        '11.4 mm/day 5-day RMSE at 42 ms inference',
        'Combine 7x7 windows with radar assimilation',
        'Explore the Q&A panel to verify any claim',
      ],
    },
    citations: ['doc:p7/sec-limits', 'doc:p5/table-1'],
    durationSeconds: scaleDur(14),
  });

  let cursor = 0;
  return scenes.map((s) => {
    const out: StoryboardScene = { ...s, startSeconds: cursor };
    cursor += s.durationSeconds;
    return out;
  });
}

export const FIXTURE_QA_EVAL_SET = [
  {
    question: 'What is MonsoonFormer 5-day RMSE compared to Full-Attention Transformer?',
    expectedCitations: ['doc:p5/table-1', 'doc:p5/sec-results'],
    shouldAnswer: true,
  },
  {
    question: 'What is the limitation beyond day 7 and what does Rao et al. say?',
    expectedCitations: ['doc:p7/sec-limits', 'https://doi.org/10.1029/2024GL109821'],
    shouldAnswer: true,
  },
  {
    question: 'What was the GDP growth rate of Brazil in 1994?',
    expectedCitations: [],
    shouldAnswer: false,
  },
];
