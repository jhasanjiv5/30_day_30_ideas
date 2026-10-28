import React from 'react';
import { Flashcard, GoetheLevel } from '../types';
import { X, Trophy, Flame, Brain, CheckCircle2 } from 'lucide-react';
import { isCardDue } from '../utils/sm2';

interface StatsModalProps {
  isOpen: boolean;
  onClose: () => void;
  deck: Flashcard[];
}

export const StatsModal: React.FC<StatsModalProps> = ({ isOpen, onClose, deck }) => {
  if (!isOpen) return null;

  const totalCards = deck.length;
  const dueCards = deck.filter(isCardDue).length;
  const masteredCards = deck.filter((c) => c.repetitions >= 3).length;
  const learningCards = deck.filter((c) => c.repetitions > 0 && c.repetitions < 3).length;
  const unstudiedCards = deck.filter((c) => c.repetitions === 0).length;

  const levels: GoetheLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  const levelCounts = levels.map((lvl) => {
    const cards = deck.filter((c) => c.level === lvl);
    const mastered = cards.filter((c) => c.repetitions >= 3).length;
    return {
      level: lvl,
      total: cards.length,
      mastered,
      pct: cards.length > 0 ? Math.round((mastered / cards.length) * 100) : 0,
    };
  });

  const overallRetention = totalCards > 0 ? Math.round((masteredCards / totalCards) * 100) : 0;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="w-full max-w-md bg-white rounded-3xl p-6 shadow-2xl border border-black/8 space-y-5 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between pb-2 border-b border-neutral-100">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-orange-50 text-orange-600">
              <Trophy className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-neutral-900">
                Spaced Repetition Stats
              </h3>
              <p className="text-xs text-neutral-500">
                Anki SM-2 Goethe Memory Retention
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

        {/* Primary metric cards */}
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-neutral-50 border border-neutral-200/70 rounded-2xl p-3.5 space-y-1">
            <div className="flex items-center justify-between text-neutral-400">
              <span className="text-[11px] font-semibold uppercase tracking-wider">
                Total Words
              </span>
              <Brain className="w-4 h-4 text-blue-500" />
            </div>
            <div className="text-2xl font-bold text-neutral-900">
              {totalCards}
            </div>
            <div className="text-[11px] text-neutral-500">
              {dueCards} cards due today
            </div>
          </div>

          <div className="bg-neutral-50 border border-neutral-200/70 rounded-2xl p-3.5 space-y-1">
            <div className="flex items-center justify-between text-neutral-400">
              <span className="text-[11px] font-semibold uppercase tracking-wider">
                Mastery Rate
              </span>
              <Flame className="w-4 h-4 text-orange-500" />
            </div>
            <div className="text-2xl font-bold text-neutral-900">
              {overallRetention}%
            </div>
            <div className="text-[11px] text-neutral-500">
              {masteredCards} mastered cards
            </div>
          </div>
        </div>

        {/* Card Stage Breakdown */}
        <div className="space-y-2 pt-1">
          <div className="text-xs font-semibold text-neutral-700">
            Memory Stages
          </div>
          <div className="space-y-1.5 text-xs">
            <div className="flex items-center justify-between text-neutral-600">
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
                Mastered (3+ reviews)
              </span>
              <span className="font-semibold text-neutral-900">{masteredCards}</span>
            </div>
            <div className="flex items-center justify-between text-neutral-600">
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-blue-500"></span>
                Learning in Progress
              </span>
              <span className="font-semibold text-neutral-900">{learningCards}</span>
            </div>
            <div className="flex items-center justify-between text-neutral-600">
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-neutral-300"></span>
                New / Unstudied
              </span>
              <span className="font-semibold text-neutral-900">{unstudiedCards}</span>
            </div>
          </div>
        </div>

        {/* Goethe CEFR Levels Breakdown */}
        <div className="space-y-2 pt-2 border-t border-neutral-100">
          <div className="text-xs font-semibold text-neutral-700">
            Goethe CEFR Mastery by Level
          </div>
          <div className="space-y-2">
            {levelCounts.map((item) => (
              <div key={item.level} className="space-y-1">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-medium text-neutral-800">
                    Goethe {item.level}
                  </span>
                  <span className="text-neutral-500 text-[11px]">
                    {item.mastered} / {item.total} words · {item.pct}%
                  </span>
                </div>
                <div className="w-full h-1.5 bg-neutral-100 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-blue-600 rounded-full transition-all duration-300"
                    style={{ width: `${item.pct}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Dismiss button */}
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
