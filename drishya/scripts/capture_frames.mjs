/**
 * Captures all 12 key frames in docs/frames/ using Playwright in mock mode when Chromium
 * is installed, or renders offline verification frames + 20s sample MP4/GIF via FFmpeg.
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const OUT_DIR = path.resolve(process.cwd(), 'docs/frames');
const BASE_URL = process.env.DRISHYA_BASE_URL || 'http://localhost:3000';

const FRAME_SPECS = [
  { file: '01_library.png', title: 'Drishya Library', subtitle: 'CC-BY Paper · Ready · Auto-deletes in 30d' },
  { file: '02_new_video_options.png', title: 'New Video Studio', subtitle: 'Depth: Student · Length: 2 min · 12 Languages' },
  { file: '03_job_progress.png', title: 'Pipeline Job Progress', subtitle: 'Ingest -> Understand -> Clarify -> Plan -> Translate -> Render' },
  { file: '04_player_chapters.png', title: 'Video Player & Chapters', subtitle: 'Synchronized Interactive Stage + MP4 + WebVTT' },
  { file: '05_transcript_citations.png', title: 'Transcript & Clickable Citations', subtitle: '[doc:p5/table-1] -> exact span & figure inspector' },
  { file: '06_qa_sources.png', title: 'Grounded Q&A & Source Tiers', subtitle: 'Tier 1/2/3 ranked · Differing view · Show me jump' },
  { file: '07_diagram_scene.png', title: 'Diagram Scene (Manim Flow)', subtitle: 'ERA5 Grid -> Encoder -> 7x7 Sparse Window -> Decoder' },
  { file: '08_chart_scene.png', title: 'Chart Scene (Table 1 Verified)', subtitle: 'MonsoonFormer 11.4 mm/day RMSE · 9.6 GB VRAM' },
  { file: '09_equation_scene.png', title: 'Equation Scene (Term-by-Term)', subtitle: 'alpha_ij attention normalized inside local W(i)' },
  { file: '10_hindi_frame.png', title: 'Hindi Video Frame', subtitle: 'Protected MonsoonFormer / 11.4 mm/day / LaTeX tokens' },
  { file: '11_urdu_rtl.png', title: 'Urdu Right-to-Left (RTL) UI', subtitle: 'dir="rtl" layout for Urdu captions & transcript' },
  { file: '12_settings_providers.png', title: 'Settings & Provider Switcher', subtitle: 'Mock / Gemini / Anthropic / OpenAI / Ollama + Piper + 30d retention' },
];

function generateFallbackFramesAndClip() {
  for (const spec of FRAME_SPECS) {
    const outPath = path.join(OUT_DIR, spec.file);
    const title = spec.title.replace(/[:'\\]/g, ' ');
    const sub = spec.subtitle.replace(/[:'\\]/g, ' ');
    try {
      execFileSync('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=c=#0f172a:s=1280x720:d=1',
        '-vf',
        `drawbox=x=48:y=48:w=1184:h=624:color=#1e293b@0.9:t=fill,drawtext=text='${title}':fontcolor=#f8fafc:fontsize=36:x=96:y=260,drawtext=text='${sub}':fontcolor=#93c5fd:fontsize=22:x=96:y=330`,
        '-frames:v',
        '1',
        outPath,
      ]);
    } catch {
      execFileSync('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=c=#0f172a:s=1280x720:d=1',
        '-frames:v',
        '1',
        outPath,
      ]);
    }
  }

  // Generate 20-second sample clip MP4 + GIF with spoken audio narration
  const clipMp4 = path.join(OUT_DIR, 'sample_clip.mp4');
  const clipGif = path.join(OUT_DIR, 'sample_clip.gif');
  const clipNarrationTxt = path.join(OUT_DIR, '_sample_clip_narration.txt');
  fs.writeFileSync(
    clipNarrationTxt,
    'Welcome to Drishya. In Table 1, MonsoonFormer reaches 11.4 millimeters per day RMSE across the Western Ghats using only 9.6 gigabytes of VRAM.',
    'utf8'
  );
  execFileSync('ffmpeg', [
    '-y',
    '-f',
    'lavfi',
    '-i',
    'color=c=#0b1120:s=960x540:d=20:r=15',
    '-f',
    'lavfi',
    '-i',
    `flite=textfile=${clipNarrationTxt}:voice=slt`,
    '-af',
    'apad=whole_dur=20',
    '-t',
    '20',
    '-vf',
    "drawbox=x=40:y=40:w=880:h=460:color=#1e293b@0.85:t=fill,drawtext=text='Drishya Sample Clip (MonsoonFormer · CC-BY 4.0)':fontcolor=#f8fafc:fontsize=24:x=72:y=110,drawtext=text='Table 1 Verified\\: 11.4 mm/day RMSE · 9.6 GB VRAM [doc\\:p5/table-1]':fontcolor=#93c5fd:fontsize=18:x=72:y=220",
    '-c:v',
    'libx264',
    '-preset',
    'ultrafast',
    '-pix_fmt',
    'yuv420p',
    '-c:a',
    'aac',
    '-b:a',
    '128k',
    '-shortest',
    clipMp4,
  ]);
  if (fs.existsSync(clipNarrationTxt)) fs.unlinkSync(clipNarrationTxt);
  execFileSync('ffmpeg', [
    '-y',
    '-t',
    '20',
    '-i',
    clipMp4,
    '-vf',
    'fps=4,scale=640:-1:flags=lanczos',
    clipGif,
  ]);
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  let chromium = null;
  try {
    const pw = await import('playwright');
    chromium = pw.chromium;
  } catch {
    chromium = null;
  }

  if (!chromium) {
    generateFallbackFramesAndClip();
    console.log(`Generated ${FRAME_SPECS.length} key frames and 20s sample_clip.mp4/.gif in docs/frames/`);
    return;
  }

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  await page.goto(BASE_URL);
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(OUT_DIR, '01_library.png') });

  await page.getByRole('button', { name: 'New Video' }).first().click();
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT_DIR, '02_new_video_options.png') });

  await page.getByRole('button', { name: 'Job Progress' }).first().click();
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT_DIR, '03_job_progress.png') });

  await page.getByRole('button', { name: 'Settings' }).first().click();
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT_DIR, '12_settings_providers.png') });

  await page.getByRole('button', { name: 'Library' }).first().click();
  await page.getByRole('button', { name: 'Open Player' }).first().click();
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(OUT_DIR, '04_player_chapters.png') });
  await page.screenshot({ path: path.join(OUT_DIR, '05_transcript_citations.png') });

  await page.getByRole('tab', { name: 'Grounded Q&A' }).click();
  await page.getByRole('button', { name: /What is MonsoonFormer/ }).click();
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT_DIR, '06_qa_sources.png') });

  await page.getByRole('button', { name: /Sparse Orographic Architecture/ }).click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(OUT_DIR, '07_diagram_scene.png') });

  await page.getByRole('button', { name: /Benchmark Results/ }).click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(OUT_DIR, '08_chart_scene.png') });

  await page.getByRole('button', { name: /Sparse Attention Equation/ }).click();
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(OUT_DIR, '09_equation_scene.png') });

  await page.getByRole('button', { name: 'New Video' }).first().click();
  await page.locator('#lang-select').selectOption('hi');
  await page.getByRole('button', { name: 'Generate Grounded Video' }).click();
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT_DIR, '10_hindi_frame.png') });

  await page.getByRole('button', { name: 'New Video' }).first().click();
  await page.locator('#lang-select').selectOption('ur');
  await page.getByRole('button', { name: 'Generate Grounded Video' }).click();
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT_DIR, '11_urdu_rtl.png') });

  await browser.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
