import React, { useState } from 'react';
import { GoetheLevel, Flashcard, GOETHE_LEVELS_INFO } from '../types';
import { Sparkles, X, Loader2, CheckCircle2, AlertCircle } from 'lucide-react';
import { playHapticFeedback } from '../utils/audio';

interface GenerateModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentLevel: GoetheLevel;
  onAddCards: (newCards: Flashcard[]) => void;
  selectedModel: string;
  hapticsEnabled: boolean;
}

export const GenerateModal: React.FC<GenerateModalProps> = ({
  isOpen,
  onClose,
  currentLevel,
  onAddCards,
  selectedModel,
  hapticsEnabled,
}) => {
  const [level, setLevel] = useState<GoetheLevel>(currentLevel);
  const [count, setCount] = useState<number>(6);
  const [topic, setTopic] = useState<string>('');
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [successCount, setSuccessCount] = useState<number | null>(null);

  if (!isOpen) return null;

  const quickTopics = [
    'Alltag & Familie',
    'Arbeit & Beruf',
    'Reisen & Hotel',
    'Gesundheit & Arzt',
    'Umwelt & Technik',
    'Gesellschaft & Politik',
  ];

  const handleGenerate = async () => {
    setIsLoading(true);
    setError(null);
    setSuccessCount(null);
    if (hapticsEnabled) playHapticFeedback('tap');

    try {
      const response = await fetch('/api/generate-cards', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          level,
          count,
          topic: topic.trim() || 'general',
          model: selectedModel,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Server returned an error generating flashcards.');
      }

      if (data.cards && Array.isArray(data.cards) && data.cards.length > 0) {
        onAddCards(data.cards);
        setSuccessCount(data.cards.length);
        if (hapticsEnabled) playHapticFeedback('success');
        setTimeout(() => {
          onClose();
        }, 1200);
      } else {
        throw new Error('No flashcards were returned by Gemini.');
      }
    } catch (err: any) {
      console.error(err);
      setError(err?.message || 'Failed to connect to the Goethe lexicon generator.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="w-full max-w-md bg-white rounded-3xl p-6 shadow-2xl border border-black/8 space-y-5">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-blue-50 text-blue-600">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-neutral-900">
                Goethe Vocabulary Generator
              </h3>
              <p className="text-xs text-neutral-500">
                Curated with Google Gemini ({selectedModel})
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-neutral-100 text-neutral-400 hover:text-neutral-700 transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Level picker */}
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-neutral-700">
            Target Goethe-Zertifikat Level
          </label>
          <div className="grid grid-cols-6 gap-1 bg-neutral-100 p-1 rounded-2xl">
            {(['A1', 'A2', 'B1', 'B2', 'C1', 'C2'] as GoetheLevel[]).map((lvl) => (
              <button
                key={lvl}
                type="button"
                onClick={() => setLevel(lvl)}
                className={`py-1.5 text-xs font-semibold rounded-xl transition ${
                  level === lvl
                    ? 'bg-white text-blue-600 shadow-xs'
                    : 'text-neutral-600 hover:text-neutral-900'
                }`}
              >
                {lvl}
              </button>
            ))}
          </div>
          <p className="text-[11px] text-neutral-500 px-1">
            {GOETHE_LEVELS_INFO[level].certificate}
          </p>
        </div>

        {/* Card Count */}
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-neutral-700">
            Number of Cards
          </label>
          <div className="grid grid-cols-3 gap-2">
            {[3, 6, 10].map((num) => (
              <button
                key={num}
                type="button"
                onClick={() => setCount(num)}
                className={`py-2 text-xs font-semibold rounded-xl border transition ${
                  count === num
                    ? 'bg-neutral-900 text-white border-neutral-900'
                    : 'bg-white text-neutral-700 border-neutral-200 hover:border-neutral-300'
                }`}
              >
                {num} Cards
              </button>
            ))}
          </div>
        </div>

        {/* Optional Topic Field */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-neutral-700">
            Topic or Exam Focus (Optional)
          </label>
          <input
            type="text"
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
            placeholder="e.g. Travel, Job Interview, Environment..."
            className="w-full px-3.5 py-2 text-xs bg-neutral-50 border border-neutral-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
          />

          {/* Quick suggestions */}
          <div className="flex flex-wrap gap-1.5 pt-1">
            {quickTopics.map((item) => (
              <button
                key={item}
                type="button"
                onClick={() => setTopic(item)}
                className={`text-[10px] px-2 py-0.5 rounded-full border transition ${
                  topic === item
                    ? 'bg-blue-50 text-blue-700 border-blue-200 font-medium'
                    : 'bg-neutral-50 text-neutral-600 border-neutral-200/80 hover:bg-neutral-100'
                }`}
              >
                {item}
              </button>
            ))}
          </div>
        </div>

        {/* Feedback Messages */}
        {error && (
          <div className="flex items-start gap-2 p-3 bg-rose-50 border border-rose-200/80 rounded-xl text-xs text-rose-700">
            <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        {successCount !== null && (
          <div className="flex items-center gap-2 p-3 bg-emerald-50 border border-emerald-200/80 rounded-xl text-xs text-emerald-700">
            <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-600" />
            <span>Successfully added {successCount} verified Goethe {level} cards!</span>
          </div>
        )}

        {/* Submit button */}
        <button
          onClick={handleGenerate}
          disabled={isLoading}
          className="w-full py-3 px-4 bg-blue-600 hover:bg-blue-700 active:bg-blue-800 disabled:opacity-50 text-white text-xs font-bold rounded-2xl shadow-sm transition flex items-center justify-center gap-2 cursor-pointer"
        >
          {isLoading ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Consulting Goethe Lexicon…</span>
            </>
          ) : (
            <>
              <Sparkles className="w-4 h-4" />
              <span>Generate {count} Cards for Goethe {level}</span>
            </>
          )}
        </button>
      </div>
    </div>
  );
};
