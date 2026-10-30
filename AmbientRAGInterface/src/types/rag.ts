export interface DocumentChunk {
  id: string;
  title: string;
  category: string;
  source: string;
  text: string;
  score?: number;
  tags?: string[];
}

export interface RetrievedChunk {
  id: string;
  title: string;
  source: string;
  category: string;
  score: number;
  snippet: string;
  fullText: string;
}

export interface PacketEvent {
  step: string;
  latencyMs: number;
  details: string;
}

export interface QueryResult {
  query: string;
  answer: string;
  reasoningSteps: string[];
  retrievedChunks: RetrievedChunk[];
  citations: Array<{ id: string; title: string; score: number }>;
  factualPrecisionScore: number;
  packetEvents: PacketEvent[];
  totalLatencyMs: number;
  modelUsed: string;
}

export interface ArchitectureLayer {
  id: string;
  name: string;
  subtitle: string;
  role: string;
  decouplingMechanism: string;
  precisionImpact: string;
  techStack: string[];
  protocol: string;
  diagramColor: string;
}
