import React, { useEffect } from 'react';
import { AnkiRating, Flashcard } from '../types';
import { getIntervalPreview } from '../utils/sm2';
import { playHapticFeedback } from '../utils/audio';

interface AnkiRatingBarProps {
  card: Flashcard;
  onRate: (rating: AnkiRating) => void;
  hapticsEnabled: boolean;
}

export const AnkiRatingBar: React.FC<AnkiRatingBarProps> = ({
  card,
  onRate,
  hapticsEnabled,
}) => {
  const handleRating = (rating: AnkiRating) => {
    if (hapticsEnabled) playHapticFeedback('rating');
    onRate(rating);
  };

  // Keyboard shortcut listener for 1, 2, 3, 4
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }
      if (e.key === '1') handleRating('again');
      if (e.key === '2') handleRating('hard');
      if (e.key === '3') handleRating('good');
      if (e.key === '4') handleRating('easy');
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [card]);

  return (
    <div className="w-full pt-2 pb-1">
      <div className="grid grid-cols-4 gap-2">
        {/* Again */}
        <button
          onClick={() => handleRating('again')}
          className="group flex flex-col items-center justify-center py-2.5 px-1 rounded-2xl bg-rose-50 hover:bg-rose-100/90 active:scale-95 border border-rose-200/60 transition cursor-pointer"
        >
          <span className="text-[11px] font-mono text-rose-500/80 group-hover:text-rose-600 transition">
            {getIntervalPreview(card, 'again')}
          </span>
          <span className="text-xs font-semibold text-rose-700">
            Again
          </span>
          <span className="text-[10px] text-rose-400 font-mono mt-0.5">
            [1]
          </span>
        </button>

        {/* Hard */}
        <button
          onClick={() => handleRating('hard')}
          className="group flex flex-col items-center justify-center py-2.5 px-1 rounded-2xl bg-amber-50 hover:bg-amber-100/90 active:scale-95 border border-amber-200/60 transition cursor-pointer"
        >
          <span className="text-[11px] font-mono text-amber-500/80 group-hover:text-amber-600 transition">
            {getIntervalPreview(card, 'hard')}
          </span>
          <span className="text-xs font-semibold text-amber-700">
            Hard
          </span>
          <span className="text-[10px] text-amber-400 font-mono mt-0.5">
            [2]
          </span>
        </button>

        {/* Good */}
        <button
          onClick={() => handleRating('good')}
          className="group flex flex-col items-center justify-center py-2.5 px-1 rounded-2xl bg-blue-50 hover:bg-blue-100/90 active:scale-95 border border-blue-200/60 transition cursor-pointer"
        >
          <span className="text-[11px] font-mono text-blue-500/80 group-hover:text-blue-600 transition">
            {getIntervalPreview(card, 'good')}
          </span>
          <span className="text-xs font-semibold text-blue-700">
            Good
          </span>
          <span className="text-[10px] text-blue-400 font-mono mt-0.5">
            [3]
          </span>
        </button>

        {/* Easy */}
        <button
          onClick={() => handleRating('easy')}
          className="group flex flex-col items-center justify-center py-2.5 px-1 rounded-2xl bg-emerald-50 hover:bg-emerald-100/90 active:scale-95 border border-emerald-200/60 transition cursor-pointer"
        >
          <span className="text-[11px] font-mono text-emerald-500/80 group-hover:text-emerald-600 transition">
            {getIntervalPreview(card, 'easy')}
          </span>
          <span className="text-xs font-semibold text-emerald-700">
            Easy
          </span>
          <span className="text-[10px] text-emerald-400 font-mono mt-0.5">
            [4]
          </span>
        </button>
      </div>
    </div>
  );
};
