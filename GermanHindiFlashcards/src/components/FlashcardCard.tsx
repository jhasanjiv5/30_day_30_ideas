import React from 'react';
import { Flashcard, StudyDirection } from '../types';
import { Volume2, RotateCcw, Sparkles } from 'lucide-react';
import { speakText, playHapticFeedback } from '../utils/audio';

interface FlashcardCardProps {
  card: Flashcard;
  direction: StudyDirection;
  isRevealed: boolean;
  onFlip: () => void;
  hapticsEnabled: boolean;
}

export const FlashcardCard: React.FC<FlashcardCardProps> = ({
  card,
  direction,
  isRevealed,
  onFlip,
  hapticsEnabled,
}) => {
  const handleCardClick = () => {
    if (hapticsEnabled) playHapticFeedback('flip');
    onFlip();
  };

  const handleAudioSpeak = (e: React.MouseEvent, text: string, lang: 'de' | 'hi') => {
    e.stopPropagation();
    if (hapticsEnabled) playHapticFeedback('tap');
    speakText(text, lang);
  };

  // Gender colors according to classic German pedagogical standard:
  // der = blue, die = red, das = green
  const getArticleBadge = (article: string) => {
    if (article === 'der') {
      return <span className="text-blue-600 font-semibold">der (m.)</span>;
    }
    if (article === 'die') {
      return <span className="text-rose-600 font-semibold">die (f.)</span>;
    }
    if (article === 'das') {
      return <span className="text-emerald-600 font-semibold">das (n.)</span>;
    }
    return <span className="text-neutral-500 font-medium">{card.partOfSpeech}</span>;
  };

  return (
    <div
      className="w-full flex-1 min-h-[380px] max-h-[520px] my-auto perspective-1200 cursor-pointer select-none"
      onClick={handleCardClick}
    >
      <div
        className={`relative w-full h-full transition-transform duration-500 transform-style-3d ${
          isRevealed ? 'rotate-y-180' : ''
        }`}
      >
        {/* ===================== FRONT FACE ===================== */}
        <div
          className="absolute inset-0 w-full h-full backface-hidden bg-white rounded-[32px] p-6 sm:p-7 flex flex-col justify-between shadow-[0_12px_36px_rgba(0,0,0,0.06),0_2px_8px_rgba(0,0,0,0.04)] border border-black/8 ring-1 ring-black/5"
        >
          {/* Header row on Front */}
          <div className="flex items-center justify-between text-xs text-neutral-500">
            <div className="flex items-center gap-2">
              <span className="font-semibold text-neutral-800 tracking-wide">
                Goethe {card.level}
              </span>
              <span className="text-neutral-300">·</span>
              {getArticleBadge(card.article)}
              {card.isCustom && (
                <>
                  <span className="text-neutral-300">·</span>
                  <span className="flex items-center gap-0.5 text-blue-600 font-medium">
                    <Sparkles className="w-3 h-3" />
                    AI
                  </span>
                </>
              )}
            </div>

            {/* Quick pronunciation button on Front */}
            <button
              onClick={(e) =>
                handleAudioSpeak(
                  e,
                  direction === 'DE_TO_HI' ? card.germanWord : card.hindiMeaning,
                  direction === 'DE_TO_HI' ? 'de' : 'hi'
                )
              }
              className="p-1.5 rounded-full hover:bg-neutral-100 text-neutral-500 hover:text-neutral-900 transition"
              title="Listen to pronunciation"
            >
              <Volume2 className="w-4 h-4" />
            </button>
          </div>

          {/* Central Question Prompt */}
          <div className="flex-1 flex flex-col items-center justify-center text-center px-2 py-4">
            {direction === 'DE_TO_HI' ? (
              // German -> Hindi front
              <div className="space-y-2">
                <h2 className="text-3xl sm:text-4xl font-serif font-bold text-neutral-900 tracking-tight leading-tight">
                  {card.germanWord}
                </h2>
                {card.plural && card.plural !== '-' && (
                  <p className="text-sm text-neutral-500 font-mono">
                    Plural: {card.plural}
                  </p>
                )}
                {card.grammarNote && (
                  <p className="text-xs text-neutral-400 max-w-xs mx-auto italic mt-1">
                    {card.grammarNote}
                  </p>
                )}
              </div>
            ) : (
              // Hindi -> German front
              <div className="space-y-2">
                <h2 className="text-3xl sm:text-4xl font-bold text-neutral-900 tracking-tight leading-snug">
                  {card.hindiMeaning}
                </h2>
                <p className="text-sm font-medium text-neutral-500">
                  {card.hindiTransliteration}
                </p>
              </div>
            )}
          </div>

          {/* Front Footer */}
          <div className="flex items-center justify-center text-xs text-neutral-400 gap-1.5 pt-2 border-t border-neutral-100">
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Tap card to reveal Goethe translation</span>
          </div>
        </div>

        {/* ===================== BACK FACE (REVEAL) ===================== */}
        <div
          className="absolute inset-0 w-full h-full backface-hidden rotate-y-180 bg-white rounded-[32px] p-6 sm:p-7 flex flex-col justify-between shadow-[0_12px_36px_rgba(0,0,0,0.06),0_2px_8px_rgba(0,0,0,0.04)] border border-black/8 ring-1 ring-black/5 overflow-hidden"
        >
          {/* Header row on Back */}
          <div className="flex items-center justify-between text-xs text-neutral-500 pb-2 border-b border-neutral-100">
            <div className="flex items-center gap-2">
              <span className="font-semibold text-neutral-800">
                Goethe {card.level} Standard
              </span>
              <span className="text-neutral-300">·</span>
              {getArticleBadge(card.article)}
            </div>

            <div className="flex items-center gap-1">
              <button
                onClick={(e) =>
                  handleAudioSpeak(
                    e,
                    direction === 'DE_TO_HI' ? card.hindiMeaning : card.germanWord,
                    direction === 'DE_TO_HI' ? 'hi' : 'de'
                  )
                }
                className="p-1.5 rounded-full hover:bg-neutral-100 text-neutral-600 hover:text-neutral-900 transition"
                title="Pronounce Answer"
              >
                <Volume2 className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Scrollable details body */}
          <div className="flex-1 overflow-y-auto py-3 space-y-4 pr-1">
            {/* Primary Target Answer */}
            <div className="space-y-1">
              {direction === 'DE_TO_HI' ? (
                <div>
                  <div className="text-2xl sm:text-3xl font-bold text-neutral-900">
                    {card.hindiMeaning}
                  </div>
                  <div className="text-xs sm:text-sm font-medium text-neutral-500">
                    {card.hindiTransliteration}
                  </div>
                </div>
              ) : (
                <div>
                  <div className="text-2xl sm:text-3xl font-serif font-bold text-neutral-900">
                    {card.germanWord}
                  </div>
                  {card.plural && card.plural !== '-' && (
                    <div className="text-xs text-neutral-500 font-mono">
                      Plural: {card.plural}
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* German Synonyms Section (CEFR Goethe-aligned) */}
            {card.synonyms && card.synonyms.length > 0 && (
              <div className="space-y-1.5">
                <div className="text-[11px] font-semibold tracking-wider uppercase text-neutral-400">
                  Synonyme (Deutsch)
                </div>
                <div className="flex flex-wrap items-center gap-1.5">
                  {card.synonyms.map((syn, idx) => (
                    <button
                      key={idx}
                      onClick={(e) => handleAudioSpeak(e, syn, 'de')}
                      className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700 text-xs font-medium transition cursor-pointer"
                      title={`Pronounce "${syn}"`}
                    >
                      <span>{syn}</span>
                      <Volume2 className="w-3 h-3 text-neutral-400 hover:text-neutral-700" />
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Contextual Clarification Example Sentence */}
            <div className="space-y-1.5 pt-1 border-t border-neutral-100">
              <div className="text-[11px] font-semibold tracking-wider uppercase text-neutral-400 flex items-center justify-between">
                <span>Beispielsatz (Clarification)</span>
                <button
                  onClick={(e) => handleAudioSpeak(e, card.germanExample, 'de')}
                  className="inline-flex items-center gap-1 text-[11px] text-blue-600 hover:text-blue-700 font-medium"
                >
                  <Volume2 className="w-3 h-3" />
                  <span>Listen</span>
                </button>
              </div>

              <div className="bg-neutral-50/80 rounded-2xl p-3 border border-neutral-200/60 space-y-1.5">
                <p className="text-xs sm:text-sm font-medium text-neutral-900 leading-relaxed">
                  "{card.germanExample}"
                </p>
                <p className="text-xs text-neutral-600 leading-relaxed">
                  {card.hindiExample}
                </p>
              </div>
            </div>

            {/* Grammar / Usage Note if available */}
            {card.grammarNote && (
              <div className="text-[11px] text-neutral-500 italic bg-amber-50/60 border border-amber-200/50 rounded-xl px-2.5 py-1.5">
                <span className="font-semibold text-amber-800 not-italic mr-1">Tipp:</span>
                {card.grammarNote}
              </div>
            )}
          </div>

          {/* Footer note */}
          <div className="pt-2 text-center border-t border-neutral-100 text-[11px] text-neutral-400">
            Rate your recall below to schedule your next review
          </div>
        </div>
      </div>
    </div>
  );
};
