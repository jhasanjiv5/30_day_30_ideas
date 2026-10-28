/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { Flashcard, GoetheLevel, StudyDirection, AnkiRating, GOETHE_LEVELS_INFO } from './types';
import { INITIAL_GOETHE_DECK } from './data/goetheSeedData';
import { calculateSM2, isCardDue } from './utils/sm2';
import { speakText, playHapticFeedback } from './utils/audio';

import { IPhoneShell } from './components/IPhoneShell';
import { TopNavBar } from './components/TopNavBar';
import { FlashcardCard } from './components/FlashcardCard';
import { AnkiRatingBar } from './components/AnkiRatingBar';
import { GenerateModal } from './components/GenerateModal';
import { StatsModal } from './components/StatsModal';
import { DeckLibraryModal } from './components/DeckLibraryModal';
import { SettingsModal } from './components/SettingsModal';
import { Sparkles, CheckCircle2, RotateCcw, ArrowRight } from 'lucide-react';

const STORAGE_KEY_DECK = 'goethe_anki_deck_v1';
const STORAGE_KEY_LEVEL = 'goethe_anki_level_v1';
const STORAGE_KEY_DIR = 'goethe_anki_dir_v1';
const STORAGE_KEY_FRAME = 'goethe_anki_phone_frame_v1';
const STORAGE_KEY_MODEL = 'goethe_anki_model_v1';
const STORAGE_KEY_AUTOPLAY = 'goethe_anki_autoplay_v1';
const STORAGE_KEY_HAPTICS = 'goethe_anki_haptics_v1';

export default function App() {
  // Load persistent state from localStorage
  const [deck, setDeck] = useState<Flashcard[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_DECK);
      if (saved) {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      }
    } catch (e) {
      console.warn('Could not load deck from localStorage, using initial Goethe deck', e);
    }
    return INITIAL_GOETHE_DECK;
  });

  const [level, setLevel] = useState<GoetheLevel>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_LEVEL) as GoetheLevel;
      if (['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].includes(saved)) return saved;
    } catch {}
    return 'B1';
  });

  const [direction, setDirection] = useState<StudyDirection>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_DIR) as StudyDirection;
      if (['DE_TO_HI', 'HI_TO_DE'].includes(saved)) return saved;
    } catch {}
    return 'DE_TO_HI';
  });

  const [isPhoneFrame, setIsPhoneFrame] = useState<boolean>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_FRAME);
      if (saved !== null) return JSON.parse(saved);
    } catch {}
    return true; // Start in iPhone frame for authentic iOS aesthetic
  });

  const [selectedModel, setSelectedModel] = useState<string>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_MODEL);
      if (saved) return saved;
    } catch {}
    return 'gemini-3.8-flash';
  });

  const [autoPlayAudio, setAutoPlayAudio] = useState<boolean>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_AUTOPLAY);
      if (saved !== null) return JSON.parse(saved);
    } catch {}
    return false;
  });

  const [hapticsEnabled, setHapticsEnabled] = useState<boolean>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_HAPTICS);
      if (saved !== null) return JSON.parse(saved);
    } catch {}
    return true;
  });

  // Active study session state
  const [currentIndex, setCurrentIndex] = useState<number>(0);
  const [isRevealed, setIsRevealed] = useState<boolean>(false);

  // Modals state
  const [isGenerateOpen, setIsGenerateOpen] = useState<boolean>(false);
  const [isStatsOpen, setIsStatsOpen] = useState<boolean>(false);
  const [isLibraryOpen, setIsLibraryOpen] = useState<boolean>(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState<boolean>(false);

  // Persist deck changes
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_DECK, JSON.stringify(deck));
    } catch (e) {
      console.error('Failed to save deck', e);
    }
  }, [deck]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_LEVEL, level);
    } catch {}
  }, [level]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_DIR, direction);
    } catch {}
  }, [direction]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_FRAME, JSON.stringify(isPhoneFrame));
    } catch {}
  }, [isPhoneFrame]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_MODEL, selectedModel);
    } catch {}
  }, [selectedModel]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_AUTOPLAY, JSON.stringify(autoPlayAudio));
    } catch {}
  }, [autoPlayAudio]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_HAPTICS, JSON.stringify(hapticsEnabled));
    } catch {}
  }, [hapticsEnabled]);

  // Filter cards by active Goethe level
  const activeLevelCards = useMemo(() => {
    return deck.filter((c) => c.level === level);
  }, [deck, level]);

  // Current active card
  const currentCard = useMemo(() => {
    if (activeLevelCards.length === 0) return null;
    if (currentIndex >= activeLevelCards.length) return null;
    return activeLevelCards[currentIndex];
  }, [activeLevelCards, currentIndex]);

  // Reset card index when level changes
  const handleSelectLevel = (newLevel: GoetheLevel) => {
    setLevel(newLevel);
    setCurrentIndex(0);
    setIsRevealed(false);
  };

  // Flip card
  const handleFlipCard = useCallback(() => {
    setIsRevealed((prev) => {
      const next = !prev;
      if (next && autoPlayAudio && currentCard) {
        if (direction === 'DE_TO_HI') {
          speakText(currentCard.hindiMeaning, 'hi');
        } else {
          speakText(currentCard.germanWord, 'de');
        }
      }
      return next;
    });
  }, [autoPlayAudio, currentCard, direction]);

  // Keyboard shortcut for card flip (Space / Enter)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }
      if (e.key === ' ' || e.key === 'Enter') {
        e.preventDefault();
        handleFlipCard();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleFlipCard]);

  // Process rating using SM-2
  const handleRateCard = (rating: AnkiRating) => {
    if (!currentCard) return;

    const updatedCard = calculateSM2(currentCard, rating);

    setDeck((prevDeck) =>
      prevDeck.map((c) => (c.id === updatedCard.id ? updatedCard : c))
    );

    // Advance to next card
    setIsRevealed(false);
    if (currentIndex < activeLevelCards.length - 1) {
      setCurrentIndex((prev) => prev + 1);
    } else {
      // Completed session
      setCurrentIndex(activeLevelCards.length);
      if (hapticsEnabled) playHapticFeedback('success');
    }
  };

  // Add new cards generated by Gemini
  const handleAddCards = (newCards: Flashcard[]) => {
    setDeck((prev) => [...newCards, ...prev]);
    // If user generated for current level, point to the newly generated card
    if (newCards.length > 0 && newCards[0].level === level) {
      setCurrentIndex(0);
      setIsRevealed(false);
    }
  };

  // Delete card
  const handleDeleteCard = (id: string) => {
    setDeck((prev) => prev.filter((c) => c.id !== id));
  };

  // Reset card review stats
  const handleResetCard = (id: string) => {
    setDeck((prev) =>
      prev.map((c) =>
        c.id === id
          ? {
              ...c,
              interval: 0,
              repetitions: 0,
              easeFactor: 2.5,
              dueDate: new Date().toISOString(),
            }
          : c
      )
    );
  };

  // Restore seed dataset
  const handleResetToDefaults = () => {
    setDeck(INITIAL_GOETHE_DECK);
    setCurrentIndex(0);
    setIsRevealed(false);
  };

  // Clear progress
  const handleClearProgress = () => {
    setDeck((prev) =>
      prev.map((c) => ({
        ...c,
        interval: 0,
        repetitions: 0,
        easeFactor: 2.5,
        dueDate: new Date().toISOString(),
      }))
    );
    setCurrentIndex(0);
    setIsRevealed(false);
  };

  // Progress percentage in current session
  const progressPercent = activeLevelCards.length > 0
    ? Math.min(100, Math.round(((currentIndex) / activeLevelCards.length) * 100))
    : 0;

  return (
    <IPhoneShell
      isPhoneFrame={isPhoneFrame}
      onToggleFrame={() => setIsPhoneFrame((prev) => !prev)}
    >
      <div className="flex-1 flex flex-col justify-between h-full select-none">
        {/* Top Header & Navigation */}
        <TopNavBar
          level={level}
          onSelectLevel={handleSelectLevel}
          direction={direction}
          onToggleDirection={setDirection}
          onOpenGenerate={() => setIsGenerateOpen(true)}
          onOpenLibrary={() => setIsLibraryOpen(true)}
          onOpenStats={() => setIsStatsOpen(true)}
          onOpenSettings={() => setIsSettingsOpen(true)}
          hapticsEnabled={hapticsEnabled}
        />

        {/* Level Info & Session Progress bar */}
        <div className="px-1 py-1 space-y-1">
          <div className="flex items-center justify-between text-[11px] text-neutral-500 font-medium">
            <span className="truncate max-w-[200px]">
              {GOETHE_LEVELS_INFO[level].title} · {activeLevelCards.length} words
            </span>
            <span>
              {activeLevelCards.length > 0
                ? `${Math.min(currentIndex + 1, activeLevelCards.length)} of ${activeLevelCards.length}`
                : '0 of 0'}
            </span>
          </div>

          <div className="w-full h-1 bg-neutral-200/60 rounded-full overflow-hidden">
            <div
              className="h-full bg-neutral-900 rounded-full transition-all duration-300"
              style={{ width: `${progressPercent}%` }}
            />
          </div>
        </div>

        {/* Main Flashcard Zone */}
        {currentCard ? (
          <div className="flex-1 flex flex-col justify-between my-2">
            <FlashcardCard
              card={currentCard}
              direction={direction}
              isRevealed={isRevealed}
              onFlip={handleFlipCard}
              hapticsEnabled={hapticsEnabled}
            />

            {/* Bottom rating bar or flip hint */}
            <div className="min-h-[58px] flex items-center justify-center pt-2">
              {isRevealed ? (
                <AnkiRatingBar
                  card={currentCard}
                  onRate={handleRateCard}
                  hapticsEnabled={hapticsEnabled}
                />
              ) : (
                <button
                  onClick={handleFlipCard}
                  className="w-full py-2.5 rounded-2xl bg-white hover:bg-neutral-50 active:scale-[0.99] border border-black/8 shadow-xs text-xs font-semibold text-neutral-700 transition cursor-pointer flex items-center justify-center gap-1.5"
                >
                  <RotateCcw className="w-3.5 h-3.5 text-neutral-400" />
                  <span>Tap Card or Spacebar to Reveal Answer</span>
                </button>
              )}
            </div>
          </div>
        ) : (
          // Session Completed / Empty State
          <div className="flex-1 flex flex-col items-center justify-center text-center p-6 space-y-4 my-auto bg-white rounded-3xl border border-black/8 shadow-sm">
            <div className="w-14 h-14 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center">
              <CheckCircle2 className="w-8 h-8" />
            </div>

            <div className="space-y-1">
              <h2 className="text-xl font-bold text-neutral-900">
                Goethe {level} Session Completed
              </h2>
              <p className="text-xs text-neutral-500 max-w-xs leading-relaxed">
                You've reviewed all available words in this batch. Generate fresh Goethe-certified vocabulary with Gemini or restart.
              </p>
            </div>

            <div className="w-full space-y-2 pt-2">
              <button
                onClick={() => {
                  if (hapticsEnabled) playHapticFeedback('tap');
                  setIsGenerateOpen(true);
                }}
                className="w-full py-3 px-4 rounded-2xl bg-blue-600 hover:bg-blue-700 active:scale-[0.99] text-white font-bold text-xs shadow-sm transition flex items-center justify-center gap-2 cursor-pointer"
              >
                <Sparkles className="w-4 h-4" />
                <span>Fetch More Words with Gemini AI</span>
              </button>

              <button
                onClick={() => {
                  if (hapticsEnabled) playHapticFeedback('tap');
                  setCurrentIndex(0);
                  setIsRevealed(false);
                }}
                className="w-full py-2.5 px-4 rounded-2xl bg-neutral-100 hover:bg-neutral-200 active:scale-[0.99] text-neutral-800 font-semibold text-xs transition flex items-center justify-center gap-2 cursor-pointer"
              >
                <RotateCcw className="w-3.5 h-3.5 text-neutral-500" />
                <span>Review This Deck Again</span>
              </button>

              {/* Quick jump to next level */}
              {level !== 'C2' && (
                <button
                  onClick={() => {
                    const nextLevels: Record<GoetheLevel, GoetheLevel> = {
                      A1: 'A2',
                      A2: 'B1',
                      B1: 'B2',
                      B2: 'C1',
                      C1: 'C2',
                      C2: 'C2',
                    };
                    handleSelectLevel(nextLevels[level]);
                  }}
                  className="w-full py-2 px-4 text-xs font-semibold text-neutral-500 hover:text-neutral-900 transition flex items-center justify-center gap-1 cursor-pointer"
                >
                  <span>Continue to Goethe {level === 'A1' ? 'A2' : level === 'A2' ? 'B1' : level === 'B1' ? 'B2' : level === 'B2' ? 'C1' : 'C2'}</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Modals */}
      <GenerateModal
        isOpen={isGenerateOpen}
        onClose={() => setIsGenerateOpen(false)}
        currentLevel={level}
        onAddCards={handleAddCards}
        selectedModel={selectedModel}
        hapticsEnabled={hapticsEnabled}
      />

      <StatsModal
        isOpen={isStatsOpen}
        onClose={() => setIsStatsOpen(false)}
        deck={deck}
      />

      <DeckLibraryModal
        isOpen={isLibraryOpen}
        onClose={() => setIsLibraryOpen(false)}
        deck={deck}
        onDeleteCard={handleDeleteCard}
        onResetCard={handleResetCard}
        hapticsEnabled={hapticsEnabled}
      />

      <SettingsModal
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
        selectedModel={selectedModel}
        onSelectModel={setSelectedModel}
        autoPlayAudio={autoPlayAudio}
        onToggleAutoPlay={setAutoPlayAudio}
        hapticsEnabled={hapticsEnabled}
        onToggleHaptics={setHapticsEnabled}
        onResetToDefaults={handleResetToDefaults}
        onClearProgress={handleClearProgress}
      />
    </IPhoneShell>
  );
}
