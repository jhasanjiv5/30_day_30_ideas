import {
  DocumentModel,
  ResearchNote,
  ResearchSketch,
  VideoArtifact,
} from '../types.ts';

function escapeHtml(raw: string): string {
  return raw
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function safeColor(hex: string): string {
  return /^#[0-9a-fA-F]{6}$/.test(hex) ? hex : '#1d4ed8';
}

export function renderSketchSvgMarkup(sketch: ResearchSketch): string {
  const w = Math.max(120, Math.min(1200, Math.round(sketch.width)));
  const h = Math.max(80, Math.min(800, Math.round(sketch.height)));
  const paths = sketch.strokes
    .map((stroke) => {
      const pts = stroke.points
        .map((pt) => `${Number(pt.x).toFixed(1)},${Number(pt.y).toFixed(1)}`)
        .join(' ');
      return `<polyline fill="none" stroke="${safeColor(stroke.color)}" stroke-width="${Math.max(1, Math.min(16, stroke.width))}" stroke-linecap="round" stroke-linejoin="round" points="${pts}" />`;
    })
    .join('\n');

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" style="max-width:100%;height:auto;background:#fbfcfe;background-image:radial-gradient(#d5dce6 1px,transparent 1px);background-size:16px 16px;border:1px solid #cbd5e1;border-radius:8px;">\n${paths}\n</svg>`;
}

export function buildPortableHtmlNotebook(params: {
  doc: DocumentModel;
  video?: VideoArtifact;
  notes: ResearchNote[];
  sketches: ResearchSketch[];
}): string {
  const { doc, video, notes, sketches } = params;
  const exportedAt = new Date().toISOString();

  const noteCardsHtml =
    notes.length === 0
      ? '<p class="muted">No user notes recorded yet.</p>'
      : notes
          .map(
            (n) => `
          <div class="card note-${escapeHtml(n.colorTag)}">
            <div class="meta">Page ${n.page} · <code>${escapeHtml(n.citationKey)}</code> · ${escapeHtml(new Date(n.createdAt).toLocaleString())}</div>
            <h4>${escapeHtml(n.title)}</h4>
            <p>${escapeHtml(n.body)}</p>
          </div>`
          )
          .join('\n');

  const sketchCardsHtml =
    sketches.length === 0
      ? '<p class="muted">No user sketches recorded yet.</p>'
      : sketches
          .map(
            (sk) => `
          <div class="card">
            <div class="meta">Page ${sk.page} · <code>${escapeHtml(sk.citationKey)}</code> · Vector SVG (${sk.strokes.length} strokes)</div>
            <h4>${escapeHtml(sk.title)}</h4>
            <div class="sketch-frame">${renderSketchSvgMarkup(sk)}</div>
          </div>`
          )
          .join('\n');

  const paragraphsHtml = doc.paragraphs
    .map(
      (p) => `
      <div class="para">
        <div class="meta">${escapeHtml(p.sectionTitle)} · Page ${p.page} · <code>${escapeHtml(p.citationKey)}</code></div>
        <p>${escapeHtml(p.text)}</p>
      </div>`
    )
    .join('\n');

  const tablesHtml = doc.tables
    .map(
      (t) => `
      <div class="card">
        <div class="meta">${escapeHtml(t.label)} · Page ${t.page} · <code>${escapeHtml(t.citationKey)}</code></div>
        <p><strong>${escapeHtml(t.caption)}</strong></p>
        <table>
          <thead><tr>${t.columns.map((c) => `<th>${escapeHtml(c)}</th>`).join('')}</tr></thead>
          <tbody>
            ${t.rows.map((r) => `<tr>${t.columns.map((c) => `<td>${escapeHtml(String(r[c] ?? ''))}</td>`).join('')}</tr>`).join('')}
          </tbody>
        </table>
      </div>`
    )
    .join('\n');

  const equationsHtml = doc.equations
    .map(
      (eq) => `
      <div class="card">
        <div class="meta">${escapeHtml(eq.label)} · Page ${eq.page} · <code>${escapeHtml(eq.citationKey)}</code></div>
        <pre><code>${escapeHtml(eq.latex)}</code></pre>
        <p>${escapeHtml(eq.description)}</p>
      </div>`
    )
    .join('\n');

  const transcriptHtml = video
    ? video.scenes
        .map(
          (sc) => `
        <div class="card">
          <div class="meta">Scene ${sc.order} (${sc.startSeconds}s – ${sc.startSeconds + sc.durationSeconds}s) · ${escapeHtml(sc.visualSpec.kind.toUpperCase())}</div>
          <h4>${escapeHtml(sc.translatedChapterTitle || sc.chapterTitle)}</h4>
          <p>${escapeHtml(sc.translatedNarration || sc.narration)}</p>
          <div class="meta">Citations: ${sc.citations.map((c) => `<code>${escapeHtml(c)}</code>`).join(' · ')}</div>
        </div>`
        )
        .join('\n')
    : '<p class="muted">No video storyboard generated yet.</p>';

  const clarificationsHtml = video
    ? video.clarifications
        .map(
          (c) => `
        <div class="card">
          <div class="meta">Tier ${c.tier} · ${escapeHtml(c.providerName)} · ${c.year}${c.confidenceLabel === 'lower confidence' ? ' · <strong>Lower confidence</strong>' : ''}${c.viewLabel ? ` · <strong>${escapeHtml(c.viewLabel)}</strong>` : ''}</div>
          <h4>${escapeHtml(c.title)}</h4>
          <p>“${escapeHtml(c.quote)}”</p>
          <div class="meta"><code>${escapeHtml(c.url)}</code></div>
        </div>`
        )
        .join('\n')
    : '';

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(doc.title)} — Drishya Portable Research Notebook</title>
  <style>
    :root { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: #0f172a; background: #f8fafc; }
    body { max-width: 960px; margin: 0 auto; padding: 32px 20px 64px; line-height: 1.6; }
    header { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 12px; padding: 24px; margin-bottom: 24px; }
    h1 { margin: 8px 0; font-size: 1.65rem; line-height: 1.25; }
    h2 { margin-top: 32px; font-size: 1.2rem; border-bottom: 1px solid #cbd5e1; padding-bottom: 6px; }
    h4 { margin: 6px 0; font-size: 1rem; }
    section { margin-bottom: 28px; }
    .meta { font-size: 0.78rem; color: #475569; margin-bottom: 4px; }
    .muted { font-size: 0.88rem; color: #64748b; }
    .card, .para { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 16px; margin: 12px 0; }
    .note-amber { background: #fffbeb; border-color: #fde68a; }
    .note-blue { background: #eff6ff; border-color: #bfdbfe; }
    .note-emerald { background: #ecfdf5; border-color: #a7f3d0; }
    code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.84em; background: #f1f5f9; padding: 1px 5px; border-radius: 4px; }
    pre { overflow-x: auto; background: #0f172a; color: #f8fafc; padding: 12px; border-radius: 8px; }
    pre code { background: transparent; padding: 0; color: inherit; }
    table { width: 100%; border-collapse: collapse; font-size: 0.85rem; margin-top: 8px; }
    th, td { text-align: left; border-bottom: 1px solid #e2e8f0; padding: 6px 8px; }
    th { color: #475569; font-weight: 600; }
    .sketch-frame { margin-top: 10px; }
    @media print { body { background: #fff; padding: 0; } .card, .para, header { break-inside: avoid; } }
  </style>
</head>
<body>
  <header>
    <div class="meta">Drishya Portable Research Archive · Platform-Independent HTML Notebook · Exported ${escapeHtml(exportedAt)}</div>
    <h1>${escapeHtml(doc.title)}</h1>
    <div class="meta">${escapeHtml(doc.authors.join(', '))} · ${escapeHtml(doc.venue)} (${doc.year}) · License: ${escapeHtml(doc.license)}</div>
    ${doc.sourceUrl ? `<div class="meta">Source URL: <code>${escapeHtml(doc.sourceUrl)}</code></div>` : ''}
  </header>

  <section>
    <h2>1. Research Notes (${notes.length})</h2>
    ${noteCardsHtml}
  </section>

  <section>
    <h2>2. Vector Sketches (${sketches.length})</h2>
    ${sketchCardsHtml}
  </section>

  <section>
    <h2>3. Extracted Document Text &amp; Citation Spans (${doc.paragraphs.length})</h2>
    ${paragraphsHtml}
    ${tablesHtml}
    ${equationsHtml}
  </section>

  <section>
    <h2>4. Narrated Video Storyboard &amp; Citations</h2>
    ${transcriptHtml}
  </section>

  ${clarificationsHtml ? `<section><h2>5. External Clarifications (Ranked by Tier)</h2>${clarificationsHtml}</section>` : ''}
</body>
</html>`;
}

export function buildMarkdownNotebook(params: {
  doc: DocumentModel;
  video?: VideoArtifact;
  notes: ResearchNote[];
  sketches: ResearchSketch[];
}): string {
  const { doc, video, notes, sketches } = params;
  const lines: string[] = [
    `# ${doc.title}`,
    '',
    `- **Authors:** ${doc.authors.join(', ')}`,
    `- **Venue & Year:** ${doc.venue} (${doc.year})`,
    `- **License:** ${doc.license}`,
    ...(doc.sourceUrl ? [`- **Source URL:** ${doc.sourceUrl}`] : []),
    `- **Exported:** ${new Date().toISOString()}`,
    '',
    '---',
    '',
    `## 1. Annotated Research Notes (${notes.length})`,
    '',
  ];

  if (notes.length === 0) {
    lines.push('_No notes recorded._', '');
  } else {
    for (const n of notes) {
      lines.push(`### ${n.title} (\`${n.citationKey}\`, Page ${n.page})`);
      lines.push(n.body);
      lines.push('');
    }
  }

  lines.push(`## 2. Sketches (${sketches.length})`, '');
  if (sketches.length === 0) {
    lines.push('_No sketches recorded._', '');
  } else {
    for (const sk of sketches) {
      lines.push(`### ${sk.title} (\`${sk.citationKey}\`, Page ${sk.page})`);
      lines.push(renderSketchSvgMarkup(sk));
      lines.push('');
    }
  }

  lines.push('## 3. Document Spans & Data', '');
  for (const p of doc.paragraphs) {
    lines.push(`- **[${p.citationKey}] (${p.sectionTitle}, p.${p.page}):** ${p.text}`);
  }
  lines.push('');

  for (const tbl of doc.tables) {
    lines.push(`### ${tbl.label}: ${tbl.caption} (\`${tbl.citationKey}\`)`, '');
    lines.push(`| ${tbl.columns.join(' | ')} |`);
    lines.push(`| ${tbl.columns.map(() => '---').join(' | ')} |`);
    for (const r of tbl.rows) {
      lines.push(`| ${tbl.columns.map((c) => String(r[c] ?? '')).join(' | ')} |`);
    }
    lines.push('');
  }

  for (const eq of doc.equations) {
    lines.push(`### ${eq.label} (\`${eq.citationKey}\`)`, '', '$$', eq.latex, '$$', '', eq.description, '');
  }

  if (video) {
    lines.push('## 4. Grounded Video Transcript', '');
    for (const sc of video.scenes) {
      lines.push(
        `### ${sc.order}. ${sc.translatedChapterTitle || sc.chapterTitle} (${sc.startSeconds}s–${sc.startSeconds + sc.durationSeconds}s)`
      );
      lines.push(sc.translatedNarration || sc.narration);
      lines.push(`Citations: ${sc.citations.map((c) => `\`${c}\``).join(', ')}`);
      lines.push('');
    }

    lines.push('## 5. External Clarification Sources', '');
    for (const c of video.clarifications) {
      lines.push(
        `- **Tier ${c.tier} (${c.providerName}, ${c.year})**${c.viewLabel ? ` [${c.viewLabel}]` : ''}${c.confidenceLabel === 'lower confidence' ? ' [Lower confidence]' : ''}: [${c.title}](${c.url}) — "${c.quote}"`
      );
    }
    lines.push('');
  }

  return lines.join('\n');
}

export function buildJsonResearchArchive(params: {
  doc: DocumentModel;
  video?: VideoArtifact;
  notes: ResearchNote[];
  sketches: ResearchSketch[];
}): string {
  return JSON.stringify(
    {
      schemaVersion: 'drishya-research-bundle/v1',
      exportedAt: new Date().toISOString(),
      document: params.doc,
      notes: params.notes,
      sketches: params.sketches,
      videoSummary: params.video
        ? {
            id: params.video.id,
            depth: params.video.depth,
            lengthTarget: params.video.lengthTarget,
            language: params.video.language,
            durationSeconds: params.video.durationSeconds,
            chapters: params.video.chapters,
            scenes: params.video.scenes,
            clarifications: params.video.clarifications,
          }
        : null,
    },
    null,
    2
  );
}
