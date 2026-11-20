import { useMemo, useState } from 'react';
import { Info, MapPin, ShieldCheck } from 'lucide-react';
import type { POC, ResourceNode } from '../types/domain.ts';
import { CloudServiceLogo, GoogleCloudLogo } from './BrandVisuals.tsx';
import { MermaidDiagram } from './MermaidDiagram.tsx';
import { CheckStatusLabel } from './StatusIndicator.tsx';

interface ArchitectureMapViewProps {
  poc: POC;
}

function sanitizeNodeId(id: string): string {
  return id.replace(/[^a-zA-Z0-9_]/g, '_');
}

export function ArchitectureMapView({ poc }: ArchitectureMapViewProps) {
  const resources = poc.environment.resources;
  const [selectedId, setSelectedId] = useState<string>(resources[0]?.id ?? '');
  const [showTechnical, setShowTechnical] = useState(false);

  const selectedNode: ResourceNode | undefined =
    resources.find((r) => r.id === selectedId) ?? resources[0];

  const mermaidDef = useMemo(() => {
    const lines: string[] = ['flowchart LR'];
    for (const node of resources) {
      const safeId = sanitizeNodeId(node.id);
      const label = node.business_label.replace(/"/g, "'");
      lines.push(`  ${safeId}["${label}"]`);
    }
    for (const node of resources) {
      const fromId = sanitizeNodeId(node.id);
      for (const dep of node.depends_on) {
        const toId = sanitizeNodeId(dep);
        lines.push(`  ${fromId} --> ${toId}`);
      }
    }
    return lines.join('\n');
  }, [resources]);

  const linkedChecks = useMemo(() => {
    if (!selectedNode) return [];
    return poc.checks.filter((c) => selectedNode.linked_check_types.includes(c.check_type));
  }, [poc.checks, selectedNode]);

  return (
    <section aria-labelledby="arch-map-heading" className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1
            id="arch-map-heading"
            className="text-2xl font-bold tracking-tight text-[#242424] sm:text-3xl"
          >
            How {poc.name} Is Built
          </h1>
          <p className="mt-1 max-w-2xl text-sm text-[#605E5C]">
            Auto-generated from live environment inventory using plain business labels. Select any
            component below to inspect what it does and where data resides.
          </p>
        </div>

        <button
          type="button"
          onClick={() => setShowTechnical((v) => !v)}
          className="inline-flex min-h-[40px] items-center gap-2 self-start rounded border border-[#8A8886] bg-white px-3.5 py-2 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1] whitespace-nowrap shrink-0"
        >
          <Info className="h-4 w-4 text-[#605E5C]" aria-hidden="true" />
          <span>{showTechnical ? 'Hide Cloud Details' : 'Show Cloud Details'}</span>
        </button>
      </div>

      <MermaidDiagram
        definition={mermaidDef}
        ariaLabel={`System architecture flow diagram for ${poc.name}`}
      />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div className="lg:col-span-5">
          <div className="ms-card overflow-hidden">
            <div className="border-b border-[#E1DFDD] bg-[#F3F2F1] px-4 py-2.5 text-xs font-semibold text-[#605E5C]">
              System Components ({resources.length})
            </div>
            <div className="divide-y divide-[#EDEBE9]">
              {resources.map((node) => {
                const active = selectedNode?.id === node.id;
                return (
                  <button
                    key={node.id}
                    type="button"
                    onClick={() => setSelectedId(node.id)}
                    aria-pressed={active}
                    className={`flex w-full min-h-[48px] items-center justify-between gap-3 px-4 py-3 text-left transition-colors ${
                      active
                        ? 'bg-[#EFF6F1] text-[#0E6B38]'
                        : 'bg-white text-[#242424] hover:bg-[#FAF9F8]'
                    }`}
                  >
                    <div className="flex min-w-0 items-center gap-3">
                      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-white">
                        <CloudServiceLogo serviceName={node.gcp_service} className="h-5 w-5" />
                      </div>
                      <div className="min-w-0">
                        <div className="truncate text-sm font-semibold">{node.business_label}</div>
                        <div className="mt-0.5 text-xs text-[#605E5C] tabular-nums">
                          {node.region} · Est. ${node.monthly_base_cost_usd}/mo
                        </div>
                      </div>
                    </div>
                    <span className="text-xs font-semibold text-[#0E6B38] whitespace-nowrap shrink-0">
                      {active ? 'Selected' : 'Inspect'}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        <div className="lg:col-span-7">
          {selectedNode ? (
            <div className="ms-card overflow-hidden">
              <div className="border-b border-[#E1DFDD] bg-[#F3F2F1] px-6 py-2.5 text-xs font-semibold text-[#605E5C]">
                Component Properties
              </div>
              <div className="p-6 space-y-5">
                <div className="flex items-start gap-3.5">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-[#FAF9F8]">
                    <CloudServiceLogo serviceName={selectedNode.gcp_service} className="h-6 w-6" />
                  </div>
                  <div>
                    <h2 className="text-xl font-semibold text-[#242424]">
                      {selectedNode.business_label}
                    </h2>
                    <p className="mt-1.5 text-base leading-relaxed text-[#323130]">
                      {selectedNode.plain_description}
                    </p>
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-4 border-t border-[#EDEBE9] pt-4 sm:grid-cols-2">
                  <div>
                    <div className="flex items-center gap-1.5 text-xs font-medium text-[#605E5C]">
                      <MapPin className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
                      <span>Data &amp; Hosting Location</span>
                    </div>
                    <div className="mt-1 text-sm font-semibold text-[#242424]">
                      {poc.environment.region_display}{' '}
                      <span className="font-mono text-xs font-normal text-[#605E5C]">
                        ({selectedNode.region})
                      </span>
                    </div>
                  </div>

                  <div>
                    <div className="flex items-center gap-1.5 text-xs font-medium text-[#605E5C]">
                      <ShieldCheck className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
                      <span>Estimated Baseline Cost</span>
                    </div>
                    <div className="mt-1 font-mono text-sm font-semibold text-[#242424] tabular-nums">
                      ${selectedNode.monthly_base_cost_usd}/month
                    </div>
                  </div>
                </div>

                {showTechnical && (
                  <div className="flex items-start gap-3 rounded border border-[#E1DFDD] bg-[#FAF9F8] p-3.5 text-xs text-[#323130]">
                    <GoogleCloudLogo className="mt-0.5 h-5 w-5 shrink-0" />
                    <div className="space-y-1">
                      <div>
                        <span className="font-semibold text-[#242424]">Cloud resource:</span>{' '}
                        {selectedNode.gcp_service}
                      </div>
                      <div>
                        <span className="font-semibold text-[#242424]">Sizing tier:</span>{' '}
                        {selectedNode.tier}
                      </div>
                      <div>
                        <span className="font-semibold text-[#242424]">Resource ID:</span>{' '}
                        <span className="font-mono">{selectedNode.id}</span>
                      </div>
                    </div>
                  </div>
                )}

                <div className="border-t border-[#EDEBE9] pt-4">
                  <div className="text-xs font-semibold text-[#242424]">
                    Verification checks covering this component
                  </div>
                  {linkedChecks.length === 0 ? (
                    <p className="mt-2 text-xs text-[#605E5C]">
                      Covered indirectly via overall environment checks.
                    </p>
                  ) : (
                    <ul className="mt-2 divide-y divide-[#EDEBE9]">
                      {linkedChecks.map((chk) => (
                        <li
                          key={chk.id}
                          className="flex items-center justify-between gap-3 py-2.5 text-sm"
                        >
                          <span className="text-[#323130]">{chk.plain_explanation}</span>
                          <CheckStatusLabel status={chk.status} />
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </section>
  );
}
