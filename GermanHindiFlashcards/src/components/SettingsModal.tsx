import React from 'react';
import { X, Cpu, Volume2, Sparkles, RefreshCw, AlertTriangle, ShieldCheck } from 'lucide-react';
import { playHapticFeedback } from '../utils/audio';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  selectedModel: string;
  onSelectModel: (model: string) => void;
  autoPlayAudio: boolean;
  onToggleAutoPlay: (enabled: boolean) => void;
  hapticsEnabled: boolean;
  onToggleHaptics: (enabled: boolean) => void;
  onResetToDefaults: () => void;
  onClearProgress: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  selectedModel,
  onSelectModel,
  autoPlayAudio,
  onToggleAutoPlay,
  hapticsEnabled,
  onToggleHaptics,
  onResetToDefaults,
  onClearProgress,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="w-full max-w-md bg-white rounded-3xl p-6 shadow-2xl border border-black/8 space-y-5 max-h-[88vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between pb-2 border-b border-neutral-100">
          <div>
            <h3 className="text-base font-bold text-neutral-900">
              Preferences
            </h3>
            <p className="text-xs text-neutral-500">
              Goethe Anki Configuration
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-neutral-100 text-neutral-400 hover:text-neutral-700 transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Section 1: AI Model Engine (Default: Gemini 3.8 Flash) */}
        <div className="space-y-2">
          <div className="flex items-center gap-1.5 text-xs font-semibold text-neutral-700">
            <Cpu className="w-4 h-4 text-blue-600" />
            <span>Underlying AI Model (Swappable)</span>
          </div>

          <div className="bg-neutral-50 border border-neutral-200/80 rounded-2xl p-2 space-y-1">
            <label
              className={`flex items-start gap-3 p-2.5 rounded-xl transition cursor-pointer ${
                selectedModel === 'gemini-3.8-flash'
                  ? 'bg-white shadow-xs border border-blue-500/30'
                  : 'hover:bg-neutral-100'
              }`}
            >
              <input
                type="radio"
                name="ai-model"
                value="gemini-3.8-flash"
                checked={selectedModel === 'gemini-3.8-flash'}
                onChange={() => onSelectModel('gemini-3.8-flash')}
                className="mt-0.5 text-blue-600 focus:ring-blue-500"
              />
              <div className="space-y-0.5">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-neutral-900">
                    Google Gemini 3.8 Flash
                  </span>
                  <span className="text-[10px] font-semibold text-blue-600 bg-blue-50 px-1.5 py-0.2 rounded-sm">
                    Default
                  </span>
                </div>
                <p className="text-[11px] text-neutral-500">
                  Recommended for Goethe vocabulary generation with deep linguistic precision.
                </p>
              </div>
            </label>

            <label
              className={`flex items-start gap-3 p-2.5 rounded-xl transition cursor-pointer ${
                selectedModel === 'gemini-3.1-flash-lite'
                  ? 'bg-white shadow-xs border border-blue-500/30'
                  : 'hover:bg-neutral-100'
              }`}
            >
              <input
                type="radio"
                name="ai-model"
                value="gemini-3.1-flash-lite"
                checked={selectedModel === 'gemini-3.1-flash-lite'}
                onChange={() => onSelectModel('gemini-3.1-flash-lite')}
                className="mt-0.5 text-blue-600 focus:ring-blue-500"
              />
              <div className="space-y-0.5">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-neutral-900">
                    Google Gemini 3.1 Flash Lite
                  </span>
                  <span className="text-[10px] font-semibold text-neutral-500 bg-neutral-200 px-1.5 py-0.2 rounded-sm">
                    Fast
                  </span>
                </div>
                <p className="text-[11px] text-neutral-500">
                  Lightweight, high-speed generation for quick multi-word batches.
                </p>
              </div>
            </label>
          </div>

          <div className="flex items-center gap-1.5 text-[11px] text-emerald-700 bg-emerald-50/70 p-2.5 rounded-xl border border-emerald-200/50">
            <ShieldCheck className="w-4 h-4 shrink-0 text-emerald-600" />
            <span>Secure server-side proxy handles all Gemini API generation automatically.</span>
          </div>
        </div>

        {/* Section 2: Audio & Feedback */}
        <div className="space-y-2 pt-1 border-t border-neutral-100">
          <div className="text-xs font-semibold text-neutral-700">
            Audio & Interaction
          </div>

          <div className="space-y-2">
            <label className="flex items-center justify-between p-3 bg-neutral-50 rounded-2xl border border-neutral-200/60 cursor-pointer">
              <div className="space-y-0.5">
                <div className="text-xs font-semibold text-neutral-900">
                  Auto-pronounce on Card Flip
                </div>
                <div className="text-[11px] text-neutral-500">
                  Speaks the answer aloud automatically when revealed
                </div>
              </div>
              <input
                type="checkbox"
                checked={autoPlayAudio}
                onChange={(e) => onToggleAutoPlay(e.target.checked)}
                className="w-4 h-4 text-blue-600 rounded-sm focus:ring-blue-500"
              />
            </label>

            <label className="flex items-center justify-between p-3 bg-neutral-50 rounded-2xl border border-neutral-200/60 cursor-pointer">
              <div className="space-y-0.5">
                <div className="text-xs font-semibold text-neutral-900">
                  Tactile Audio Haptics
                </div>
                <div className="text-[11px] text-neutral-500">
                  Subtle iOS mechanical click sound on flip and grading
                </div>
              </div>
              <input
                type="checkbox"
                checked={hapticsEnabled}
                onChange={(e) => onToggleHaptics(e.target.checked)}
                className="w-4 h-4 text-blue-600 rounded-sm focus:ring-blue-500"
              />
            </label>
          </div>
        </div>

        {/* Section 3: Deck Maintenance */}
        <div className="space-y-2 pt-1 border-t border-neutral-100">
          <div className="text-xs font-semibold text-neutral-700">
            Deck Management
          </div>

          <div className="space-y-2">
            <button
              onClick={() => {
                if (hapticsEnabled) playHapticFeedback('tap');
                if (confirm('Restore default Goethe-certified vocabulary deck for levels A1 through C2?')) {
                  onResetToDefaults();
                }
              }}
              className="w-full flex items-center justify-between p-3 bg-neutral-50 hover:bg-neutral-100 rounded-2xl border border-neutral-200/60 text-xs text-neutral-800 font-medium transition cursor-pointer"
            >
              <div className="flex items-center gap-2">
                <RefreshCw className="w-4 h-4 text-blue-600" />
                <span>Restore Goethe Standard Decks (A1–C2)</span>
              </div>
              <span className="text-[11px] text-neutral-400">Default</span>
            </button>

            <button
              onClick={() => {
                if (hapticsEnabled) playHapticFeedback('tap');
                if (confirm('Reset review intervals and mastery progress back to 0 for all cards?')) {
                  onClearProgress();
                }
              }}
              className="w-full flex items-center justify-between p-3 bg-rose-50 hover:bg-rose-100/80 rounded-2xl border border-rose-200/60 text-xs text-rose-700 font-medium transition cursor-pointer"
            >
              <div className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-rose-600" />
                <span>Reset Anki Memory Progress</span>
              </div>
              <span className="text-[11px] text-rose-500">Reset</span>
            </button>
          </div>
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
