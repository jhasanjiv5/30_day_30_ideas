import React, { useState, useEffect } from 'react';
import { Wifi, BatteryMedium, Smartphone, Maximize2 } from 'lucide-react';

interface IPhoneShellProps {
  children: React.ReactNode;
  isPhoneFrame: boolean;
  onToggleFrame: () => void;
}

export const IPhoneShell: React.FC<IPhoneShellProps> = ({
  children,
  isPhoneFrame,
  onToggleFrame,
}) => {
  const [currentTime, setCurrentTime] = useState<string>('9:41');

  useEffect(() => {
    const updateClock = () => {
      const now = new Date();
      let hours = now.getHours();
      const minutes = now.getMinutes().toString().padStart(2, '0');
      // Format 12-hour or 24-hour style
      setCurrentTime(`${hours}:${minutes}`);
    };
    updateClock();
    const interval = setInterval(updateClock, 30000);
    return () => clearInterval(interval);
  }, []);

  if (!isPhoneFrame) {
    return (
      <div className="min-h-screen bg-[#f5f5f7] flex flex-col items-center justify-start p-2 sm:p-4 md:p-6">
        <div className="w-full max-w-2xl bg-white/80 backdrop-blur-xl border border-black/8 rounded-3xl shadow-xl overflow-hidden min-h-[780px] flex flex-col relative">
          {/* Top subtle bar with frame switch */}
          <div className="px-6 py-2.5 bg-neutral-100/70 border-b border-black/5 flex items-center justify-between text-xs text-neutral-500">
            <span className="font-medium text-neutral-700 flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-500 inline-block"></span>
              Goethe Anki · Web Preview
            </span>
            <button
              onClick={onToggleFrame}
              className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-white border border-neutral-200 hover:bg-neutral-50 text-neutral-700 font-medium transition cursor-pointer shadow-xs"
              title="Switch to Apple iPhone Device Frame"
            >
              <Smartphone className="w-3.5 h-3.5" />
              <span>iPhone Frame</span>
            </button>
          </div>
          <div className="flex-1 flex flex-col p-4 sm:p-6 overflow-hidden">
            {children}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-neutral-900 flex flex-col items-center justify-center p-2 sm:p-6">
      {/* Viewport frame switcher button floating top-right */}
      <div className="w-full max-w-sm mb-3 flex items-center justify-between px-2 text-xs text-neutral-400">
        <span className="font-medium text-neutral-300">Apple iPhone 16 Pro View</span>
        <button
          onClick={onToggleFrame}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-neutral-800 hover:bg-neutral-700 text-neutral-200 border border-neutral-700 transition cursor-pointer"
          title="Switch to full web layout"
        >
          <Maximize2 className="w-3.5 h-3.5" />
          <span>Full Window</span>
        </button>
      </div>

      {/* Realistic iPhone Device Shell */}
      <div className="w-full max-w-[400px] h-[820px] bg-black rounded-[54px] p-3 shadow-2xl ring-1 ring-white/10 ring-offset-2 ring-offset-black relative flex flex-col">
        {/* Device border edge highlights */}
        <div className="absolute inset-0 rounded-[54px] border-[3px] border-neutral-700/60 pointer-events-none" />

        {/* Inner Phone Screen Container */}
        <div className="w-full h-full bg-[#f5f5f7] rounded-[44px] overflow-hidden flex flex-col relative">
          
          {/* iOS Dynamic Island & Status Bar */}
          <div className="h-11 px-7 flex items-center justify-between select-none relative z-20 pt-1">
            {/* Clock */}
            <span className="text-[14px] font-semibold tracking-tight text-neutral-900">
              {currentTime}
            </span>

            {/* Dynamic Island pill */}
            <div className="absolute left-1/2 -translate-x-1/2 top-2.5 w-[112px] h-[30px] bg-black rounded-full flex items-center justify-center shadow-sm">
              <div className="w-2.5 h-2.5 rounded-full bg-neutral-950 mr-auto ml-3 border border-neutral-800" />
              <div className="w-2.5 h-2.5 rounded-full bg-blue-900/40 mr-3 border border-blue-600/30" />
            </div>

            {/* Icons */}
            <div className="flex items-center gap-1.5 text-neutral-900">
              <Wifi className="w-3.5 h-3.5" strokeWidth={2.4} />
              <BatteryMedium className="w-5 h-4" strokeWidth={2.4} />
            </div>
          </div>

          {/* Screen Content */}
          <div className="flex-1 flex flex-col overflow-hidden px-4 pb-2">
            {children}
          </div>

          {/* iOS Home Indicator Bar */}
          <div className="h-5 flex items-center justify-center pb-1">
            <div className="w-32 h-1 bg-neutral-900/30 rounded-full" />
          </div>
        </div>
      </div>
    </div>
  );
};
