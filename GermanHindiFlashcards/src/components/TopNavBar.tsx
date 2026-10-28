import React from 'react';
import { GoetheLevel, StudyDirection, GOETHE_LEVELS_INFO } from '../types';
import { ChevronDown, Sparkles, BookOpen, BarChart3, Settings } from 'lucide-react';
import { playHapticFeedback } from '../utils/audio';

interface TopNavBarProps {
  level: GoetheLevel;
  onSelectLevel: (lvl: GoetheLevel) => void;
  direction: StudyDirection;
  onToggleDirection: (dir: StudyDirection) => void;
  onOpenGenerate: () => void;
  onOpenLibrary: () => void;
  onOpenStats: () => void;
  onOpenSettings: () => void;
  hapticsEnabled: boolean;
}

export const TopNavBar: React.FC<TopNavBarProps> = ({
  level,
  onSelectLevel,
  direction,
  onToggleDirection,
  onOpenGenerate,
  onOpenLibrary,
  onOpenStats,
  onOpenSettings,
  hapticsEnabled,
}) => {
  const levels: GoetheLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  const handleLevelChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (hapticsEnabled) playHapticFeedback('tap');
    onSelectLevel(e.target.value as GoetheLevel);
  };

  const handleDirectionChange = (newDir: StudyDirection) => {
    if (newDir !== direction) {
      if (hapticsEnabled) playHapticFeedback('tap');
      onToggleDirection(newDir);
    }
  };

  return (
    <div className="flex flex-col gap-2.5 pt-1 pb-2">
      {/* Primary header bar */}
      <div className="flex items-center justify-between">
        {/* Goethe Level selector pill */}
        <div className="relative inline-flex items-center">
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/90 backdrop-blur-md shadow-xs border border-black/8 hover:bg-neutral-50 transition cursor-pointer">
            <span className="w-2 h-2 rounded-full bg-blue-500"></span>
            <span className="text-[13px] font-semibold text-neutral-900">
              Goethe {level}
            </span>
            <ChevronDown className="w-3.5 h-3.5 text-neutral-500" />
          </div>
          <select
            value={level}
            onChange={handleLevelChange}
            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer text-sm"
            aria-label="Select Goethe Level"
          >
            {levels.map((lvl) => (
              <option key={lvl} value={lvl}>
                {lvl} · {GOETHE_LEVELS_INFO[lvl].certificate}
              </option>
            ))}
          </select>
        </div>

        {/* Quick actions cluster */}
        <div className="flex items-center gap-1">
          <button
            onClick={() => {
              if (hapticsEnabled) playHapticFeedback('tap');
              onOpenGenerate();
            }}
            className="p-2 rounded-full bg-white/90 backdrop-blur-md border border-black/8 text-neutral-700 hover:text-blue-600 hover:bg-blue-50/80 transition cursor-pointer shadow-xs active:scale-95"
            title="Generate Goethe Cards with Gemini"
          >
            <Sparkles className="w-4 h-4 text-blue-600" />
          </button>

          <button
            onClick={() => {
              if (hapticsEnabled) playHapticFeedback('tap');
              onOpenLibrary();
            }}
            className="p-2 rounded-full bg-white/90 backdrop-blur-md border border-black/8 text-neutral-700 hover:text-neutral-950 hover:bg-neutral-100 transition cursor-pointer shadow-xs active:scale-95"
            title="Deck Library & Search"
          >
            <BookOpen className="w-4 h-4" />
          </button>

          <button
            onClick={() => {
              if (hapticsEnabled) playHapticFeedback('tap');
              onOpenStats();
            }}
            className="p-2 rounded-full bg-white/90 backdrop-blur-md border border-black/8 text-neutral-700 hover:text-neutral-950 hover:bg-neutral-100 transition cursor-pointer shadow-xs active:scale-95"
            title="Progress & Anki Stats"
          >
            <BarChart3 className="w-4 h-4" />
          </button>

          <button
            onClick={() => {
              if (hapticsEnabled) playHapticFeedback('tap');
              onOpenSettings();
            }}
            className="p-2 rounded-full bg-white/90 backdrop-blur-md border border-black/8 text-neutral-700 hover:text-neutral-950 hover:bg-neutral-100 transition cursor-pointer shadow-xs active:scale-95"
            title="Preferences & Model"
          >
            <Settings className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Segmented control for study direction (DE -> HI vs HI -> DE) */}
      <div className="flex items-center justify-between gap-2">
        <div className="w-full bg-neutral-200/70 p-0.5 rounded-full flex relative select-none">
          <button
            type="button"
            onClick={() => handleDirectionChange('DE_TO_HI')}
            className={`flex-1 py-1 text-[12px] font-semibold rounded-full transition-all duration-200 cursor-pointer flex items-center justify-center gap-1.5 ${
              direction === 'DE_TO_HI'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-600 hover:text-neutral-900'
            }`}
          >
            <span>Deutsch</span>
            <span className="text-[10px] text-neutral-400">→</span>
            <span>हिन्दी</span>
          </button>

          <button
            type="button"
            onClick={() => handleDirectionChange('HI_TO_DE')}
            className={`flex-1 py-1 text-[12px] font-semibold rounded-full transition-all duration-200 cursor-pointer flex items-center justify-center gap-1.5 ${
              direction === 'HI_TO_DE'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-600 hover:text-neutral-900'
            }`}
          >
            <span>हिन्दी</span>
            <span className="text-[10px] text-neutral-400">→</span>
            <span>Deutsch</span>
          </button>
        </div>
      </div>
    </div>
  );
};
