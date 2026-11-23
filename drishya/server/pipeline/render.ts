import { GoogleGenAI } from '@google/genai';
import { execFile } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { promisify } from 'node:util';
import { LanguageCode, StoryboardScene, TTSProviderName } from '../types.ts';

const execFileAsync = promisify(execFile);

export const STORAGE_ROOT = path.resolve(
  process.cwd(),
  process.env.DRISHYA_STORAGE_DIR || 'data/storage'
);

export function ensureStorageDir(subPath = ''): string {
  const resolved = path.resolve(STORAGE_ROOT, subPath);
  if (resolved !== STORAGE_ROOT && !resolved.startsWith(STORAGE_ROOT + path.sep)) {
    throw new Error('Invalid storage path boundary.');
  }
  fs.mkdirSync(resolved, { recursive: true });
  return resolved;
}

function formatVttTime(seconds: number): string {
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  const ms = Math.round((seconds - Math.floor(seconds)) * 1000);
  const pad = (n: number, w = 2) => String(n).padStart(w, '0');
  return `${pad(hrs)}:${pad(mins)}:${pad(secs)}.${pad(ms, 3)}`;
}

export function buildWebVTT(scenes: StoryboardScene[]): string {
  const lines: string[] = ['WEBVTT', ''];
  let idx = 1;
  for (const scene of scenes) {
    const start = scene.startSeconds;
    const end = scene.startSeconds + scene.durationSeconds;
    const captionText = scene.translatedNarration || scene.narration;
    lines.push(`${idx}`);
    lines.push(`${formatVttTime(start)} --> ${formatVttTime(end)}`);
    lines.push(`[${scene.translatedChapterTitle || scene.chapterTitle}] ${captionText}`);
    lines.push('');
    idx += 1;
  }
  return lines.join('\n');
}

function buildFfmetadataChapters(scenes: StoryboardScene[]): string {
  const lines = [';FFMETADATA1', 'title=Drishya Grounded Research Video', ''];
  for (const scene of scenes) {
    const startMs = Math.round(scene.startSeconds * 1000);
    const endMs = Math.round((scene.startSeconds + scene.durationSeconds) * 1000);
    lines.push('[CHAPTER]');
    lines.push('TIMEBASE=1/1000');
    lines.push(`START=${startMs}`);
    lines.push(`END=${endMs}`);
    lines.push(`title=${(scene.translatedChapterTitle || scene.chapterTitle).replace(/[=;\n]/g, ' ')}`);
    lines.push('');
  }
  return lines.join('\n');
}

function sanitizeForFlite(text: string): string {
  return text
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201C\u201D]/g, '"')
    .replace(/[\u2013\u2014]/g, ', ')
    .replace(/\bmm\/day\b/gi, 'millimeters per day')
    .replace(/\balpha_ij\b/g, 'alpha i j')
    .replace(/\bq_i\b/g, 'q i')
    .replace(/\bk_j\b/g, 'k j')
    .replace(/\bd_k\b/g, 'd k')
    .replace(/\bW\(i\)/g, 'W of i')
    .replace(/[^A-Za-z0-9.,!?;:'"()\-%\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function synthesizeGeminiSceneWav(
  text: string,
  outWavPath: string
): Promise<boolean> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === 'MY_GEMINI_API_KEY') return false;

  try {
    const ai = new GoogleGenAI({
      apiKey,
      httpOptions: {
        headers: {
          'User-Agent': 'aistudio-build',
        },
      },
    });
    const response = await ai.models.generateContent({
      model: 'gemini-3.8-flash-lite-tts',
      contents: [
        {
          role: 'user',
          parts: [
            {
              text,
              speechMetadata: {
                style: 'Clear, engaging scientific podcast narrator',
              },
            },
          ],
        },
      ],
      config: {
        responseModalities: ['AUDIO'],
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: { voiceName: 'Kore' },
          },
        },
      },
    });
    const base64Audio = response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
    if (!base64Audio) return false;
    fs.writeFileSync(outWavPath, Buffer.from(base64Audio, 'base64'));
    return true;
  } catch {
    return false;
  }
}

/**
 * Synthesizes per-scene spoken narration WAV padded/fitted cleanly to each scene's duration,
 * then concatenates into a single continuous narration.wav synced 1:1 with the video chapters.
 */
async function synthesizeFullNarrationWav(params: {
  videoDir: string;
  scenes: StoryboardScene[];
  language: LanguageCode;
  ttsProvider: TTSProviderName;
  captionsOnly: boolean;
  mockMode: boolean;
}): Promise<{ wavPath: string; synthesizedSpeech: boolean }> {
  const fullWavPath = path.join(params.videoDir, 'narration.wav');
  const totalDuration = Math.max(
    10,
    params.scenes.reduce((sum, s) => sum + s.durationSeconds, 0)
  );

  if (params.captionsOnly) {
    await execFileAsync('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      `anullsrc=r=24000:cl=mono:d=${totalDuration}`,
      '-c:a',
      'pcm_s16le',
      fullWavPath,
    ]);
    return { wavPath: fullWavPath, synthesizedSpeech: false };
  }

  const sceneWavPaths: string[] = [];
  let anySpeech = false;

  for (const scene of params.scenes) {
    const rawClipPath = path.join(params.videoDir, `scene_${scene.order}_raw.wav`);
    const paddedClipPath = path.join(params.videoDir, `scene_${scene.order}_fit.wav`);
    const txtPath = path.join(params.videoDir, `scene_${scene.order}.txt`);

    let usedCloud = false;
    if (!params.mockMode && params.ttsProvider === 'cloud') {
      const spokenText = scene.translatedNarration || scene.narration;
      usedCloud = await synthesizeGeminiSceneWav(spokenText, rawClipPath);
    }

    if (!usedCloud) {
      // Offline libflite TTS inside FFmpeg (synthesizes audible English narration cleanly)
      const fliteText = sanitizeForFlite(scene.narration) || scene.chapterTitle;
      fs.writeFileSync(txtPath, fliteText, 'utf8');
      try {
        await execFileAsync('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          `flite=textfile=${txtPath}:voice=slt`,
          '-ar',
          '24000',
          '-ac',
          '1',
          rawClipPath,
        ]);
        anySpeech = true;
      } catch {
        await execFileAsync('ffmpeg', [
          '-y',
          '-f',
          'lavfi',
          '-i',
          `anullsrc=r=24000:cl=mono:d=${scene.durationSeconds}`,
          rawClipPath,
        ]);
      }
    } else {
      anySpeech = true;
    }

    // Pad or trim each scene clip to exact scene.durationSeconds so chapters never drift
    await execFileAsync('ffmpeg', [
      '-y',
      '-i',
      rawClipPath,
      '-af',
      `aresample=24000,apad=whole_dur=${scene.durationSeconds}`,
      '-t',
      String(scene.durationSeconds),
      '-ar',
      '24000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      paddedClipPath,
    ]);

    sceneWavPaths.push(paddedClipPath);
  }

  const concatTxt = path.join(params.videoDir, 'audio_concat.txt');
  fs.writeFileSync(
    concatTxt,
    sceneWavPaths.map((p) => `file '${p}'`).join('\n'),
    'utf8'
  );

  await execFileAsync('ffmpeg', [
    '-y',
    '-f',
    'concat',
    '-safe',
    '0',
    '-i',
    concatTxt,
    '-c:a',
    'pcm_s16le',
    fullWavPath,
  ]);

  // Clean up temporary per-scene intermediates
  for (const p of sceneWavPaths) {
    const raw = p.replace('_fit.wav', '_raw.wav');
    const txt = p.replace('_fit.wav', '.txt');
    for (const f of [p, raw, txt]) {
      if (fs.existsSync(f)) fs.unlinkSync(f);
    }
  }
  if (fs.existsSync(concatTxt)) fs.unlinkSync(concatTxt);

  return { wavPath: fullWavPath, synthesizedSpeech: anySpeech };
}

/**
 * Generates a real playable MP4 video with spoken audio narration, chapter markers,
 * WebVTT subtitles, and clean scene frames via FFmpeg.
 */
export async function assembleVideoArtifacts(params: {
  videoId: string;
  documentId: string;
  title: string;
  scenes: StoryboardScene[];
  language?: LanguageCode;
  ttsProvider?: TTSProviderName;
  captionsOnly?: boolean;
  mockMode?: boolean;
}): Promise<{ mp4Path: string; vttPath: string; wavPath: string; totalDuration: number }> {
  const videoDir = ensureStorageDir(path.join('videos', params.videoId));
  const vttPath = path.join(videoDir, 'captions.vtt');
  const mp4Path = path.join(videoDir, 'podcast.mp4');
  const metaPath = path.join(videoDir, 'chapters.ffmeta');

  const vttContent = buildWebVTT(params.scenes);
  fs.writeFileSync(vttPath, vttContent, 'utf8');
  fs.writeFileSync(metaPath, buildFfmetadataChapters(params.scenes), 'utf8');

  const totalDuration = Math.max(
    10,
    params.scenes.reduce((sum, s) => sum + s.durationSeconds, 0)
  );

  const { wavPath } = await synthesizeFullNarrationWav({
    videoDir,
    scenes: params.scenes,
    language: params.language ?? 'en',
    ttsProvider: params.ttsProvider ?? 'mock',
    captionsOnly: params.captionsOnly ?? false,
    mockMode: params.mockMode ?? true,
  });

  // Build crisp drawtext overlays per scene onto a clean dark observatory 1280x720 canvas
  const safeTitle = params.title.slice(0, 58).replace(/[:'\\]/g, ' ');
  const filters: string[] = [
    `drawbox=x=0:y=0:w=1280:h=84:color=#0f172a@0.95:t=fill`,
    `drawtext=text='DRISHYA  |  ${safeTitle}':fontcolor=#f8fafc:fontsize=22:x=48:y=30`,
  ];

  for (const scene of params.scenes) {
    const t0 = scene.startSeconds.toFixed(2);
    const t1 = (scene.startSeconds + scene.durationSeconds).toFixed(2);
    const chapter = (scene.translatedChapterTitle || scene.chapterTitle)
      .slice(0, 52)
      .replace(/[:'\\]/g, ' ');
    const kindLabel = scene.visualSpec.kind.toUpperCase();
    const citeLabel = scene.citations.slice(0, 2).join('  ').replace(/[:'\\]/g, ' ');

    filters.push(
      `drawtext=text='${kindLabel} · ${chapter}':fontcolor=#93c5fd:fontsize=30:x=64:y=160:enable='between(t,${t0},${t1})'`,
      `drawtext=text='Citations\\: ${citeLabel}':fontcolor=#cbd5e1:fontsize=18:x=64:y=636:enable='between(t,${t0},${t1})'`
    );
  }

  try {
    await execFileAsync(
      'ffmpeg',
      [
        '-y',
        '-f',
        'lavfi',
        '-i',
        `color=c=#0b1120:s=1280x720:d=${totalDuration}:r=6`,
        '-i',
        wavPath,
        '-i',
        metaPath,
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-map_metadata',
        '2',
        '-vf',
        filters.join(','),
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
        '-movflags',
        '+faststart',
        mp4Path,
      ],
      { timeout: 60000 }
    );
  } catch {
    await execFileAsync(
      'ffmpeg',
      [
        '-y',
        '-f',
        'lavfi',
        '-i',
        `color=c=#0b1120:s=1280x720:d=${totalDuration}:r=6`,
        '-i',
        wavPath,
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
        mp4Path,
      ],
      { timeout: 60000 }
    );
  }

  return { mp4Path, vttPath, wavPath, totalDuration };
}

export function deleteVideoArtifacts(videoId: string): void {
  const dir = path.resolve(STORAGE_ROOT, 'videos', videoId);
  if (dir.startsWith(STORAGE_ROOT + path.sep) && fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
