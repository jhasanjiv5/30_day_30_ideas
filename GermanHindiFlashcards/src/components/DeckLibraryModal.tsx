import React, { useState } from 'react';
import { Flashcard, GoetheLevel } from '../types';
import { X, Search, Volume2, Trash2, RotateCcw } from 'lucide-react';
import { speakText, playHapticFeedback } from '../utils/audio';
import { isCardDue } from '../utils/sm2';

interface DeckLibraryModalProps {
  isOpen: boolean;
  onClose: () => void;
  deck: Flashcard[];
  onDeleteCard: (id: string) => void;
  onResetCard: (id: string) => void;
  hapticsEnabled: boolean;
}

export const DeckLibraryModal: React.FC<DeckLibraryModalProps> = ({
  isOpen,
  onClose,
  deck,
  onDeleteCard,
  onResetCard,
  hapticsEnabled,
}) => {
  const [search, setSearch] = useState<string>('');
  const [selectedLevel, setSelectedLevel] = useState<string>('ALL');

  if (!isOpen) return null;

  const levels: (GoetheLevel | 'ALL')[] = ['ALL', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  const filteredCards = deck.filter((c) => {
    const matchesLevel = selectedLevel === 'ALL' || c.level === selectedLevel;
    const query = search.toLowerCase().trim();
    const matchesSearch =
      !query ||
      c.germanWord.toLowerCase().includes(query) ||
      c.hindiMeaning.toLowerCase().includes(query) ||
      c.hindiTransliteration.toLowerCase().includes(query) ||
      c.synonyms.some((s) => s.toLowerCase().includes(query));

    return matchesLevel && matchesSearch;
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="w-full max-w-lg bg-white rounded-3xl p-6 shadow-2xl border border-black/8 space-y-4 max-h-[88vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between pb-2 border-b border-neutral-100">
          <div>
            <h3 className="text-base font-bold text-neutral-900">
              Goethe Vocabulary Library
            </h3>
            <p className="text-xs text-neutral-500">
              {filteredCards.length} of {deck.length} flashcards shown
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-neutral-100 text-neutral-400 hover:text-neutral-700 transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Search Bar */}
        <div className="relative">
          <Search className="w-4 h-4 text-neutral-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search German, Hindi, or synonyms…"
            className="w-full pl-9 pr-3.5 py-2 text-xs bg-neutral-50 border border-neutral-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
          />
        </div>

        {/* Level filter tabs */}
        <div className="flex items-center gap-1 overflow-x-auto pb-1 text-xs">
          {levels.map((lvl) => (
            <button
              key={lvl}
              onClick={() => {
                if (hapticsEnabled) playHapticFeedback('tap');
                setSelectedLevel(lvl);
              }}
              className={`px-3 py-1 rounded-full font-medium transition whitespace-nowrap cursor-pointer ${
                selectedLevel === lvl
                  ? 'bg-neutral-900 text-white'
                  : 'bg-neutral-100 text-neutral-600 hover:bg-neutral-200'
              }`}
            >
              {lvl === 'ALL' ? 'All Levels' : `Goethe ${lvl}`}
            </button>
          ))}
        </div>

        {/* Cards List */}
        <div className="flex-1 overflow-y-auto space-y-2.5 pr-1">
          {filteredCards.length === 0 ? (
            <div className="text-center py-12 text-neutral-400 text-xs">
              No flashcards found matching your criteria.
            </div>
          ) : (
            filteredCards.map((card) => {
              const due = isCardDue(card);
              return (
                <div
                  key={card.id}
                  className="p-3.5 bg-neutral-50/70 border border-neutral-200/70 rounded-2xl flex flex-col gap-2 hover:bg-neutral-50 transition"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-bold text-neutral-900 font-serif">
                          {card.germanWord}
                        </span>
                        <span className="text-[11px] font-semibold text-blue-600">
                          {card.level}
                        </span>
                        {card.article && (
                          <span className="text-[10px] text-neutral-400">
                            ({card.article})
                          </span>
                        )}
                        {due ? (
                          <span className="text-[10px] px-1.5 py-0.2 rounded-sm bg-amber-100 text-amber-800 font-medium">
                            Due
                          </span>
                        ) : (
                          <span className="text-[10px] text-neutral-400 font-mono">
                            {card.interval}d
                          </span>
                        )}
                      </div>

                      <div className="text-xs text-neutral-700 mt-0.5">
                        <span className="font-medium">{card.hindiMeaning}</span>
                        <span className="text-neutral-400 ml-1.5 text-[11px]">
                          ({card.hindiTransliteration})
                        </span>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => {
                          if (hapticsEnabled) playHapticFeedback('tap');
                          speakText(card.germanWord, 'de');
                        }}
                        className="p-1.5 rounded-lg hover:bg-neutral-200 text-neutral-500 hover:text-neutral-800 transition"
                        title="Pronounce German"
                      >
                        <Volume2 className="w-3.5 h-3.5" />
                      </button>

                      <button
                        onClick={() => {
                          if (hapticsEnabled) playHapticFeedback('tap');
                          onResetCard(card.id);
                        }}
                        className="p-1.5 rounded-lg hover:bg-neutral-200 text-neutral-400 hover:text-neutral-700 transition"
                        title="Reset Anki review interval"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                      </button>

                      <button
                        onClick={() => {
                          if (hapticsEnabled) playHapticFeedback('tap');
                          onDeleteCard(card.id);
                        }}
                        className="p-1.5 rounded-lg hover:bg-rose-100 text-neutral-400 hover:text-rose-600 transition"
                        title="Delete card"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* German synonyms */}
                  {card.synonyms.length > 0 && (
                    <div className="text-[11px] text-neutral-500 flex items-center gap-1.5 flex-wrap">
                      <span className="font-semibold text-neutral-400">Synonyme:</span>
                      {card.synonyms.map((s, idx) => (
                        <span key={idx} className="bg-white px-1.5 py-0.5 rounded-md border border-neutral-200/80">
                          {s}
                        </span>
                      ))}
                    </div>
                  )}

                  {/* Clarification sentence */}
                  <div className="text-[11px] text-neutral-500 bg-white/70 p-2 rounded-xl border border-neutral-200/50 space-y-0.5">
                    <p className="font-medium text-neutral-700">"{card.germanExample}"</p>
                    <p className="text-neutral-500">{card.hindiExample}</p>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Footer */}
        <button
          onClick={onClose}
          className="w-full py-2.5 bg-neutral-900 hover:bg-neutral-800 text-white text-xs font-semibold rounded-2xl transition cursor-pointer"
        >
          Done
        </button>
      </div>
    </div>
  );
};
