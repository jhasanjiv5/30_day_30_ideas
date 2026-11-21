import { useState } from 'react';
import { Check, Copy } from 'lucide-react';

interface CopyCommandButtonProps {
  text: string;
  label?: string;
  className?: string;
}

export function CopyCommandButton({ text, label = 'Copy', className = '' }: CopyCommandButtonProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
      } else {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.focus();
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
      }
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      setCopied(false);
    }
  };

  return (
    <button
      type="button"
      onClick={handleCopy}
      aria-label={copied ? 'Copied command' : `Copy ${text}`}
      className={`inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs font-medium whitespace-nowrap shrink-0 transition-colors cursor-pointer ${
        copied
          ? 'bg-emerald-50 text-emerald-700'
          : 'bg-white text-[#1D1D1F] hover:bg-[#E8E8ED] border border-black/[0.08]'
      } ${className}`}
    >
      {copied ? (
        <>
          <Check className="w-3.5 h-3.5 text-emerald-600" aria-hidden="true" />
          <span>Copied</span>
        </>
      ) : (
        <>
          <Copy className="w-3.5 h-3.5 text-[#6E6E73]" aria-hidden="true" />
          <span>{label}</span>
        </>
      )}
    </button>
  );
}
