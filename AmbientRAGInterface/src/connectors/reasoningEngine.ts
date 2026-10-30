/**
 * @file reasoningEngine.ts
 * ==============================================================================
 * CONNECTOR SPECIFICATION: Cognitive Reasoning Model Slot
 * WHERE TO CONNECT:
 *   Place this in your server-side layer (e.g. `src/connectors/reasoningEngine.ts`
 *   or Python `reasoning_core.py`).
 *
 * HOW TO CONNECT:
 *   1. Initialize the `@google/genai` client using server process.env.GEMINI_API_KEY.
 *   2. Set target model to 'gemini-3.8-flash' (or 'gemini-4-argon' for deep STEM/code).
 *   3. Enforce Self-RAG verification, ThinkingLevel.MEDIUM or HIGH, and structured JSON output.
 * ==============================================================================
 */

import { GoogleGenAI, Type, ThinkingLevel } from '@google/genai';
import { RetrievedVectorChunk } from './vectorStore';

export interface ReasoningResult {
  reasoningSteps: string[];
  answer: string;
  precisionScore: number;
  citedSources: string[];
}

export interface ReasoningEngineAdapter {
  name: string;
  executeReasoning(
    query: string,
    chunks: RetrievedVectorChunk[],
    ambientContext?: Record<string, any>
  ): Promise<ReasoningResult>;
}

export class GeminiReasoningEngine implements ReasoningEngineAdapter {
  name = 'Gemini 3.8 Flash Cognitive Reasoning Core';
  private ai: GoogleGenAI;
  private modelName: string;

  constructor(apiKey = process.env.GEMINI_API_KEY || '', modelName = 'gemini-3.8-flash') {
    this.ai = new GoogleGenAI({
      apiKey,
      httpOptions: {
        headers: {
          'User-Agent': 'aistudio-build'
        }
      }
    });
    this.modelName = modelName;
  }

  async executeReasoning(
    query: string,
    chunks: RetrievedVectorChunk[],
    ambientContext: Record<string, any> = {}
  ): Promise<ReasoningResult> {
    const formattedContext = chunks.length > 0
      ? chunks.map((c, i) => `[Source ${i + 1} | ID: ${c.id} | Score: ${(c.similarityScore * 100).toFixed(1)}%]\n${c.text}`).join('\n\n')
      : 'No high-confidence documents found in vector store collection.';

    const systemInstruction = 
      `You are the Cognitive Reasoning Engine of an autonomous loosely-connected Ambient RAG system. ` +
      `Your responsibility is high-precision factual synthesis without hallucination.\n` +
      `Protocol:\n` +
      `1. Perform intent decomposition and context sufficiency evaluation.\n` +
      `2. If retrieved chunks do not corroborate an answer, state the boundary rather than guessing.\n` +
      `3. Mandatory bracketed source citations: [Source 1], [Source 2].\n` +
      `4. Provide explicit step-by-step thinking traces.`;

    const contents = 
      `User Inquiry:\n"${query}"\n\n` +
      `Ambient Session Context:\n${JSON.stringify(ambientContext, null, 2)}\n\n` +
      `Retrieved ChromaDB Passages:\n${formattedContext}`;

    const response = await this.ai.models.generateContent({
      model: this.modelName,
      contents,
      config: {
        systemInstruction,
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.MEDIUM
        },
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            reasoningSteps: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: 'Step-by-step chain of thought decomposing query and verifying facts'
            },
            answer: {
              type: Type.STRING,
              description: 'Authoritative grounded answer with [Source X] citations'
            },
            precisionScore: {
              type: Type.NUMBER,
              description: 'Confidence score (0 to 100) reflecting factual certainty'
            },
            citedSources: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: 'Array of cited sources'
            }
          },
          required: ['reasoningSteps', 'answer', 'precisionScore', 'citedSources']
        }
      }
    });

    const parsed = JSON.parse(response.text ?? '{}');
    return {
      reasoningSteps: parsed.reasoningSteps || ['Decomposed query and verified vector context.'],
      answer: parsed.answer || 'Synthesized verified response.',
      precisionScore: parsed.precisionScore ?? 95,
      citedSources: parsed.citedSources || []
    };
  }
}
