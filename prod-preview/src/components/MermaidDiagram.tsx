import { useEffect, useId, useState } from 'react';
import mermaid from 'mermaid';

let mermaidInitialized = false;

interface MermaidDiagramProps {
  definition: string;
  ariaLabel: string;
}

export function MermaidDiagram({ definition, ariaLabel }: MermaidDiagramProps) {
  const rawId = useId().replace(/[^a-zA-Z0-9]/g, '');
  const [svgMarkup, setSvgMarkup] = useState<string>('');
  const [renderError, setRenderError] = useState<string | null>(null);

  useEffect(() => {
    if (!mermaidInitialized) {
      mermaid.initialize({
        startOnLoad: false,
        theme: 'base',
        securityLevel: 'strict',
        fontFamily: '"Public Sans", "Segoe UI", system-ui, sans-serif',
        themeVariables: {
          primaryColor: '#EFF6F1',
          primaryTextColor: '#242424',
          primaryBorderColor: '#107C41',
          lineColor: '#605E5C',
          secondaryColor: '#F3F2F1',
          tertiaryColor: '#FFFFFF',
          fontSize: '14px',
        },
        flowchart: {
          curve: 'linear',
          htmlLabels: true,
        },
      });
      mermaidInitialized = true;
    }

    let cancelled = false;
    (async () => {
      try {
        const { svg } = await mermaid.render(`mmd-${rawId}`, definition);
        if (!cancelled) {
          setSvgMarkup(svg);
          setRenderError(null);
        }
      } catch (err) {
        if (!cancelled) {
          setRenderError(err instanceof Error ? err.message : 'Diagram render error');
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [definition, rawId]);

  if (renderError) {
    return (
      <div className="rounded border border-[#E1DFDD] bg-[#F3F2F1] p-4 text-sm text-[#605E5C]">
        Architecture diagram could not be rendered: {renderError}
      </div>
    );
  }

  if (!svgMarkup) {
    return (
      <div
        className="h-48 w-full animate-pulse rounded border border-[#E1DFDD] bg-[#F3F2F1]"
        aria-label="Loading architecture diagram"
      />
    );
  }

  return (
    <div
      role="img"
      aria-label={ariaLabel}
      className="ms-card w-full overflow-x-auto p-5 [&>svg]:mx-auto [&>svg]:h-auto [&>svg]:max-w-full"
      dangerouslySetInnerHTML={{ __html: svgMarkup }}
    />
  );
}
