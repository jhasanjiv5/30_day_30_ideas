import { GoogleGenAI } from '@google/genai';
import { z } from 'zod';
import {
  LanguageCode,
  LLMProviderName,
  SUPPORTED_LANGUAGES,
  TTSProviderName,
} from '../types.ts';

export interface LLMCallResult<T> {
  data: T;
  provider: LLMProviderName;
  model: string;
  promptVersion: string;
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
  retried: boolean;
}

export interface LLMProvider {
  readonly name: LLMProviderName;
  generateStructured<T>(params: {
    model: string;
    promptVersion: string;
    systemPrompt: string;
    userPrompt: string;
    schema: z.ZodType<T>;
    mockFallback: () => T;
  }): Promise<LLMCallResult<T>>;
}

const COST_PER_1K_TOKENS: Record<LLMProviderName, { input: number; output: number }> = {
  mock: { input: 0, output: 0 },
  gemini: { input: 0.00015, output: 0.0006 },
  anthropic: { input: 0.003, output: 0.015 },
  openai: { input: 0.0025, output: 0.01 },
  ollama: { input: 0, output: 0 },
};

function estimateCost(provider: LLMProviderName, inTok: number, outTok: number): number {
  const rate = COST_PER_1K_TOKENS[provider];
  return Number(((inTok / 1000) * rate.input + (outTok / 1000) * rate.output).toFixed(6));
}

export class MockLLMProvider implements LLMProvider {
  readonly name: LLMProviderName = 'mock';
  async generateStructured<T>(params: {
    model: string;
    promptVersion: string;
    systemPrompt: string;
    userPrompt: string;
    schema: z.ZodType<T>;
    mockFallback: () => T;
  }): Promise<LLMCallResult<T>> {
    const raw = params.mockFallback();
    const parsed = params.schema.parse(raw);
    return {
      data: parsed,
      provider: 'mock',
      model: params.model,
      promptVersion: params.promptVersion,
      inputTokens: 420,
      outputTokens: 310,
      costUsd: 0,
      retried: false,
    };
  }
}

export class GeminiLLMProvider implements LLMProvider {
  readonly name: LLMProviderName = 'gemini';
  async generateStructured<T>(params: {
    model: string;
    promptVersion: string;
    systemPrompt: string;
    userPrompt: string;
    schema: z.ZodType<T>;
    mockFallback: () => T;
  }): Promise<LLMCallResult<T>> {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey || apiKey === 'MY_GEMINI_API_KEY') {
      throw new Error('GEMINI_API_KEY is not configured in server environment.');
    }
    const ai = new GoogleGenAI({
      apiKey,
      httpOptions: {
        headers: {
          'User-Agent': 'aistudio-build',
        },
      },
    });
    const response = await ai.models.generateContent({
      model: params.model,
      contents: params.userPrompt,
      config: {
        systemInstruction: params.systemPrompt,
        responseMimeType: 'application/json',
      },
    });
    const text = (response.text ?? '{}').trim();
    const parsedJson = JSON.parse(text);
    const parsed = params.schema.parse(parsedJson);
    const inTok = response.usageMetadata?.promptTokenCount ?? Math.ceil(params.userPrompt.length / 4);
    const outTok = response.usageMetadata?.candidatesTokenCount ?? Math.ceil(text.length / 4);
    return {
      data: parsed,
      provider: 'gemini',
      model: params.model,
      promptVersion: params.promptVersion,
      inputTokens: inTok,
      outputTokens: outTok,
      costUsd: estimateCost('gemini', inTok, outTok),
      retried: false,
    };
  }
}

export class OpenAILLMProvider implements LLMProvider {
  readonly name: LLMProviderName = 'openai';
  async generateStructured<T>(params: {
    model: string;
    promptVersion: string;
    systemPrompt: string;
    userPrompt: string;
    schema: z.ZodType<T>;
    mockFallback: () => T;
  }): Promise<LLMCallResult<T>> {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      throw new Error('OPENAI_API_KEY is not configured in server environment.');
    }
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: params.model,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: params.systemPrompt },
          { role: 'user', content: params.userPrompt },
        ],
      }),
    });
    if (!res.ok) throw new Error(`OpenAI API HTTP ${res.status}`);
    const payload = (await res.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    };
    const rawText = payload.choices?.[0]?.message?.content ?? '{}';
    const parsed = params.schema.parse(JSON.parse(rawText));
    const inTok = payload.usage?.prompt_tokens ?? 500;
    const outTok = payload.usage?.completion_tokens ?? 350;
    return {
      data: parsed,
      provider: 'openai',
      model: params.model,
      promptVersion: params.promptVersion,
      inputTokens: inTok,
      outputTokens: outTok,
      costUsd: estimateCost('openai', inTok, outTok),
      retried: false,
    };
  }
}

export class AnthropicLLMProvider implements LLMProvider {
  readonly name: LLMProviderName = 'anthropic';
  async generateStructured<T>(params: {
    model: string;
    promptVersion: string;
    systemPrompt: string;
    userPrompt: string;
    schema: z.ZodType<T>;
    mockFallback: () => T;
  }): Promise<LLMCallResult<T>> {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      throw new Error('ANTHROPIC_API_KEY is not configured in server environment.');
    }
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: params.model,
        max_tokens: 2048,
        system: params.systemPrompt,
        messages: [{ role: 'user', content: params.userPrompt }],
      }),
    });
    if (!res.ok) throw new Error(`Anthropic API HTTP ${res.status}`);
    const payload = (await res.json()) as {
      content?: Array<{ text?: string }>;
      usage?: { input_tokens?: number; output_tokens?: number };
    };
    const rawText = payload.content?.[0]?.text ?? '{}';
    const parsed = params.schema.parse(JSON.parse(rawText));
    const inTok = payload.usage?.input_tokens ?? 500;
    const outTok = payload.usage?.output_tokens ?? 350;
    return {
      data: parsed,
      provider: 'anthropic',
      model: params.model,
      promptVersion: params.promptVersion,
      inputTokens: inTok,
      outputTokens: outTok,
      costUsd: estimateCost('anthropic', inTok, outTok),
      retried: false,
    };
  }
}

export class OllamaLLMProvider implements LLMProvider {
  readonly name: LLMProviderName = 'ollama';
  async generateStructured<T>(params: {
    model: string;
    promptVersion: string;
    systemPrompt: string;
    userPrompt: string;
    schema: z.ZodType<T>;
    mockFallback: () => T;
  }): Promise<LLMCallResult<T>> {
    const baseUrl = process.env.OLLAMA_BASE_URL || 'http://localhost:11434';
    const res = await fetch(`${baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: params.model,
        format: 'json',
        stream: false,
        messages: [
          { role: 'system', content: params.systemPrompt },
          { role: 'user', content: params.userPrompt },
        ],
      }),
    });
    if (!res.ok) throw new Error(`Ollama HTTP ${res.status}`);
    const payload = (await res.json()) as { message?: { content?: string } };
    const parsed = params.schema.parse(JSON.parse(payload.message?.content ?? '{}'));
    return {
      data: parsed,
      provider: 'ollama',
      model: params.model,
      promptVersion: params.promptVersion,
      inputTokens: 480,
      outputTokens: 320,
      costUsd: 0,
      retried: false,
    };
  }
}

const PROVIDERS: Record<LLMProviderName, LLMProvider> = {
  mock: new MockLLMProvider(),
  gemini: new GeminiLLMProvider(),
  anthropic: new AnthropicLLMProvider(),
  openai: new OpenAILLMProvider(),
  ollama: new OllamaLLMProvider(),
};

/**
 * Invokes the configured LLMProvider with 1 automatic retry on schema/network error,
 * then walks the admin-defined fallbackChain if needed.
 */
export async function executeWithProviderChain<T>(params: {
  primary: LLMProviderName;
  fallbackChain: LLMProviderName[];
  models: Record<LLMProviderName, string>;
  mockMode: boolean;
  promptVersion: string;
  systemPrompt: string;
  userPrompt: string;
  schema: z.ZodType<T>;
  mockFallback: () => T;
}): Promise<LLMCallResult<T>> {
  if (params.mockMode || params.primary === 'mock') {
    return PROVIDERS.mock.generateStructured({
      model: params.models[params.primary] || 'mock-deterministic-v1',
      promptVersion: params.promptVersion,
      systemPrompt: params.systemPrompt,
      userPrompt: params.userPrompt,
      schema: params.schema,
      mockFallback: params.mockFallback,
    });
  }

  const chain = [params.primary, ...params.fallbackChain.filter((p) => p !== params.primary)];
  let lastError: unknown;

  for (const providerName of chain) {
    const adapter = PROVIDERS[providerName];
    const model = params.models[providerName];
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const result = await adapter.generateStructured({
          model,
          promptVersion: params.promptVersion,
          systemPrompt: params.systemPrompt,
          userPrompt: params.userPrompt,
          schema: params.schema,
          mockFallback: params.mockFallback,
        });
        return { ...result, retried: attempt > 0 };
      } catch (err) {
        lastError = err;
      }
    }
  }

  throw lastError instanceof Error
    ? lastError
    : new Error('All configured LLM providers in fallback chain failed.');
}

export interface TTSSynthesisResult {
  provider: TTSProviderName;
  voice: string;
  language: LanguageCode;
  durationSeconds: number;
  captionsOnly: boolean;
}

export interface TTSProvider {
  readonly name: TTSProviderName;
  synthesizeInfo(language: LanguageCode, durationSeconds: number): TTSSynthesisResult;
}

export const TTS_PROVIDERS: Record<TTSProviderName, TTSProvider> = {
  mock: {
    name: 'mock',
    synthesizeInfo(language, durationSeconds) {
      const info = SUPPORTED_LANGUAGES.find((l) => l.code === language) ?? SUPPORTED_LANGUAGES[0];
      return {
        provider: 'mock',
        voice: info.capability === 'captions_only' ? 'Captions only (No TTS voice)' : `${info.defaultVoice} [Recorded Fixture]`,
        language,
        durationSeconds,
        captionsOnly: info.capability === 'captions_only',
      };
    },
  },
  cloud: {
    name: 'cloud',
    synthesizeInfo(language, durationSeconds) {
      const info = SUPPORTED_LANGUAGES.find((l) => l.code === language) ?? SUPPORTED_LANGUAGES[0];
      return {
        provider: 'cloud',
        voice: info.defaultVoice,
        language,
        durationSeconds,
        captionsOnly: info.capability === 'captions_only',
      };
    },
  },
  piper: {
    name: 'piper',
    synthesizeInfo(language, durationSeconds) {
      const info = SUPPORTED_LANGUAGES.find((l) => l.code === language) ?? SUPPORTED_LANGUAGES[0];
      const captionsOnly = info.piperVoice === 'captions-fallback';
      return {
        provider: 'piper',
        voice: captionsOnly ? 'Captions only (Piper voice unavailable)' : info.piperVoice,
        language,
        durationSeconds,
        captionsOnly,
      };
    },
  },
};
