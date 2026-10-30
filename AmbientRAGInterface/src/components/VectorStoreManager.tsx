import React, { useState } from 'react';
import { 
  Database, 
  Plus, 
  Trash2, 
  RotateCcw, 
  Search, 
  Tag, 
  FilePlus2, 
  Layers, 
  Activity,
  CheckCircle2,
  ExternalLink
} from 'lucide-react';
import { DocumentChunk } from '../types/rag';
import { DEFAULT_CORPUS } from '../data/defaultCorpus';

interface VectorStoreManagerProps {
  documents: DocumentChunk[];
  setDocuments: React.Dispatch<React.SetStateAction<DocumentChunk[]>>;
  onQueryClick: (title: string) => void;
}

export const VectorStoreManager: React.FC<VectorStoreManagerProps> = ({
  documents,
  setDocuments,
  onQueryClick
}) => {
  const [filterQuery, setFilterQuery] = useState<string>('');
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [showAddModal, setShowAddModal] = useState<boolean>(false);

  // New Chunk Form State
  const [newTitle, setNewTitle] = useState<string>('');
  const [newCategory, setNewCategory] = useState<string>('Architecture');
  const [newSource, setNewSource] = useState<string>('');
  const [newText, setNewText] = useState<string>('');

  const categories = ['All', ...Array.from(new Set(documents.map(d => d.category)))];

  const filteredDocs = documents.filter(doc => {
    const matchesCat = selectedCategory === 'All' || doc.category === selectedCategory;
    const matchesSearch = 
      doc.title.toLowerCase().includes(filterQuery.toLowerCase()) ||
      doc.text.toLowerCase().includes(filterQuery.toLowerCase()) ||
      doc.category.toLowerCase().includes(filterQuery.toLowerCase());
    return matchesCat && matchesSearch;
  });

  const handleAddChunk = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim() || !newText.trim()) return;

    const newChunk: DocumentChunk = {
      id: `doc-custom-${Date.now().toString(36)}`,
      title: newTitle.trim(),
      category: newCategory,
      source: newSource.trim() || 'Custom Ingestion Gateway',
      text: newText.trim(),
      tags: ['User Ingested', newCategory]
    };

    setDocuments(prev => [newChunk, ...prev]);
    setNewTitle('');
    setNewSource('');
    setNewText('');
    setShowAddModal(false);
  };

  const handleDeleteChunk = (id: string) => {
    setDocuments(prev => prev.filter(d => d.id !== id));
  };

  const handleResetCorpus = () => {
    setDocuments(DEFAULT_CORPUS);
  };

  return (
    <div className="space-y-8">
      {/* Overview & ChromaDB Index Status */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 sm:p-8 shadow-sm">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          <div className="lg:col-span-7 space-y-4">
            <div className="flex items-center gap-2 text-xs font-medium text-slate-500 dark:text-slate-400">
              <span>ChromaDB Embedded Vector Store</span>
              <span aria-hidden="true">·</span>
              <span>HNSW Index Space</span>
              <span aria-hidden="true">·</span>
              <span>Cosine Metric</span>
            </div>

            <h1 className="text-2xl font-bold text-slate-900 dark:text-slate-100">
              Pluggable ChromaDB Vector Store & Knowledge Base
            </h1>

            <p className="text-sm text-slate-600 dark:text-slate-300 leading-relaxed">
              In a loosely-coupled RAG system, the vector database operates through an abstract interface. You can ingest, partition, and query dense vector embeddings without coupling client applications to the underlying storage engine.
            </p>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2">
              <div className="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700">
                <span className="text-[11px] text-slate-500 dark:text-slate-400 block">Total Chunks</span>
                <span className="text-lg font-bold font-mono tabular-nums text-slate-900 dark:text-slate-100">
                  {documents.length}
                </span>
              </div>
              <div className="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700">
                <span className="text-[11px] text-slate-500 dark:text-slate-400 block">Index Space</span>
                <span className="text-sm font-bold font-mono text-slate-900 dark:text-slate-100">
                  Cosine
                </span>
              </div>
              <div className="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700">
                <span className="text-[11px] text-slate-500 dark:text-slate-400 block">ANN Algorithm</span>
                <span className="text-sm font-bold font-mono text-slate-900 dark:text-slate-100">
                  HNSW M=16
                </span>
              </div>
              <div className="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700">
                <span className="text-[11px] text-slate-500 dark:text-slate-400 block">Ingress Latency</span>
                <span className="text-sm font-bold font-mono tabular-nums text-emerald-600 dark:text-emerald-400">
                  ~18ms
                </span>
              </div>
            </div>

            <div className="pt-2 flex items-center gap-3">
              <button
                onClick={() => setShowAddModal(true)}
                className="px-4 py-2 text-xs font-semibold rounded-lg bg-blue-600 hover:bg-blue-700 text-white shadow-sm transition-colors flex items-center gap-2"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Ingest New Document Chunk</span>
              </button>

              <button
                onClick={handleResetCorpus}
                className="px-3.5 py-2 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 transition-colors flex items-center gap-1.5"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span>Reset Default Corpus</span>
              </button>
            </div>
          </div>

          <div className="lg:col-span-5">
            <div className="relative rounded-xl overflow-hidden border border-slate-200 dark:border-slate-800 bg-slate-950 aspect-video shadow-md">
              <img
                src="/src/assets/images/chromadb_vector_space_1793306679800.jpg"
                alt="ChromaDB Latent Vector Embedding Space Visualization"
                referrerPolicy="no-referrer"
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-transparent to-transparent flex items-end p-4">
                <span className="text-xs font-medium text-slate-300">
                  Dense Semantic Clustering & High-Dimensional Vector Projections
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Filter and Search Bar */}
      <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 shadow-sm space-y-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="relative flex-1 max-w-md">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
            <input
              type="text"
              value={filterQuery}
              onChange={e => setFilterQuery(e.target.value)}
              placeholder="Search vector collection by keyword, title, or concept..."
              className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Interactive Category Segmented Control */}
          <div className="flex items-center gap-1 p-1 bg-slate-100 dark:bg-slate-800 rounded-lg overflow-x-auto">
            {categories.map(cat => (
              <button
                key={cat}
                onClick={() => setSelectedCategory(cat)}
                className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors whitespace-nowrap shrink-0 ${
                  selectedCategory === cat
                    ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm'
                    : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
                }`}
              >
                {cat}
              </button>
            ))}
          </div>
        </div>

        {/* Document Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredDocs.map(doc => (
            <div
              key={doc.id}
              className="p-5 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50/60 dark:bg-slate-950/40 flex flex-col justify-between space-y-3"
            >
              <div className="space-y-2">
                <div className="flex items-start justify-between gap-2">
                  <div className="text-xs font-bold text-slate-900 dark:text-slate-100 leading-snug">
                    {doc.title}
                  </div>
                  <button
                    onClick={() => handleDeleteChunk(doc.id)}
                    aria-label="Delete chunk"
                    className="text-slate-400 hover:text-red-500 transition-colors p-1"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>

                <div className="text-[11px] text-slate-500 dark:text-slate-400">
                  <span>{doc.category}</span>
                  <span aria-hidden="true" className="mx-1">·</span>
                  <span className="truncate">{doc.source}</span>
                </div>

                <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed line-clamp-4">
                  {doc.text}
                </p>
              </div>

              <div className="pt-2 border-t border-slate-200 dark:border-slate-800/80 flex items-center justify-between text-xs">
                <span className="font-mono text-[10px] text-slate-400 dark:text-slate-500">
                  ID: {doc.id}
                </span>
                <button
                  onClick={() => onQueryClick(doc.title)}
                  className="text-blue-600 dark:text-blue-400 hover:underline text-[11px] font-medium"
                >
                  Test Query Grounding →
                </button>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Ingestion Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-xl">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-bold text-slate-900 dark:text-slate-100">
                Ingest Document into ChromaDB Collection
              </h2>
              <button
                onClick={() => setShowAddModal(false)}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 text-sm"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleAddChunk} className="space-y-4 text-xs">
              <div>
                <label className="font-medium text-slate-700 dark:text-slate-300 block mb-1">
                  Document Title
                </label>
                <input
                  type="text"
                  required
                  value={newTitle}
                  onChange={e => setNewTitle(e.target.value)}
                  placeholder="e.g. Zero-Trust Access Token Revocation"
                  className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-lg px-3 py-2 text-xs text-slate-900 dark:text-slate-100"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="font-medium text-slate-700 dark:text-slate-300 block mb-1">
                    Category
                  </label>
                  <select
                    value={newCategory}
                    onChange={e => setNewCategory(e.target.value)}
                    className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-lg px-3 py-2 text-xs text-slate-900 dark:text-slate-100"
                  >
                    <option value="Architecture">Architecture</option>
                    <option value="Vector Store">Vector Store</option>
                    <option value="Reasoning Engine">Reasoning Engine</option>
                    <option value="Security">Security</option>
                    <option value="Domain Knowledge">Domain Knowledge</option>
                  </select>
                </div>
                <div>
                  <label className="font-medium text-slate-700 dark:text-slate-300 block mb-1">
                    Source Attribution
                  </label>
                  <input
                    type="text"
                    value={newSource}
                    onChange={e => setNewSource(e.target.value)}
                    placeholder="e.g. Internal Wiki / SecOps"
                    className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-lg px-3 py-2 text-xs text-slate-900 dark:text-slate-100"
                  />
                </div>
              </div>

              <div>
                <label className="font-medium text-slate-700 dark:text-slate-300 block mb-1">
                  Text Passage (Semantic Content for Dense Embedding)
                </label>
                <textarea
                  required
                  rows={4}
                  value={newText}
                  onChange={e => setNewText(e.target.value)}
                  placeholder="Paste or write the factual document text..."
                  className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-300 dark:border-slate-700 rounded-lg px-3 py-2 text-xs text-slate-900 dark:text-slate-100"
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-3.5 py-2 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 text-xs font-semibold rounded-lg bg-blue-600 hover:bg-blue-700 text-white transition-colors"
                >
                  Ingest & Index
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
