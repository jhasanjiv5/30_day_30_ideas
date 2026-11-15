import React from 'react';
import { Maximize2, Minus, Plus } from 'lucide-react';
import type { LineageGraph, LineageNode } from '../types/panji.ts';

interface LineageGraphCanvasProps {
  lineage: LineageGraph;
  onSelectPerson: (personId: string) => void;
}

interface PositionedNode {
  node: LineageNode;
  x: number;
  y: number;
}

const NODE_WIDTH = 178;
const NODE_HEIGHT = 68;
const H_GAP = 32;
const V_GAP = 108;

export function LineageGraphCanvas({ lineage, onSelectPerson }: LineageGraphCanvasProps) {
  const [zoom, setZoom] = React.useState(1);
  const [pan, setPan] = React.useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = React.useState(false);
  const dragOrigin = React.useRef<{ x: number; y: number; panX: number; panY: number } | null>(
    null
  );

  React.useEffect(() => {
    setZoom(1);
    setPan({ x: 0, y: 0 });
  }, [lineage.focusPerson.id]);

  const layout = React.useMemo(() => {
    const layers = new Map<number, LineageNode[]>();
    for (const n of lineage.nodes) {
      const list = layers.get(n.generationOffset) ?? [];
      list.push(n);
      layers.set(n.generationOffset, list);
    }

    const sortedOffsets = Array.from(layers.keys()).sort((a, b) => a - b);

    const genZero = layers.get(0);
    if (genZero) {
      const focus = genZero.filter((n) => n.role === 'focus');
      const sibs = genZero.filter((n) => n.role !== 'focus');
      const left = sibs.slice(0, Math.floor(sibs.length / 2));
      const right = sibs.slice(Math.floor(sibs.length / 2));
      layers.set(0, [...left, ...focus, ...right]);
    }

    let maxRowWidth = 0;
    for (const offset of sortedOffsets) {
      const count = layers.get(offset)?.length ?? 1;
      const w = count * NODE_WIDTH + Math.max(0, count - 1) * H_GAP;
      if (w > maxRowWidth) maxRowWidth = w;
    }

    const paddingX = 64;
    const paddingY = 56;
    const canvasWidth = Math.max(700, maxRowWidth + paddingX * 2);
    const canvasHeight = Math.max(
      340,
      sortedOffsets.length * NODE_HEIGHT +
        Math.max(0, sortedOffsets.length - 1) * (V_GAP - NODE_HEIGHT) +
        paddingY * 2
    );

    const positioned = new Map<string, PositionedNode>();
    sortedOffsets.forEach((offset, rowIndex) => {
      const rowNodes = layers.get(offset) ?? [];
      const rowWidth =
        rowNodes.length * NODE_WIDTH + Math.max(0, rowNodes.length - 1) * H_GAP;
      const startX = (canvasWidth - rowWidth) / 2;
      const y = paddingY + rowIndex * V_GAP;

      rowNodes.forEach((node, colIndex) => {
        const x = startX + colIndex * (NODE_WIDTH + H_GAP);
        positioned.set(node.person.id, { node, x, y });
      });
    });

    return { positioned, canvasWidth, canvasHeight };
  }, [lineage]);

  const handlePointerDown = (e: React.PointerEvent<SVGSVGElement>) => {
    if ((e.target as HTMLElement).closest('[data-node-id]')) return;
    setIsDragging(true);
    dragOrigin.current = { x: e.clientX, y: e.clientY, panX: pan.x, panY: pan.y };
  };

  const handlePointerMove = (e: React.PointerEvent<SVGSVGElement>) => {
    if (!isDragging || !dragOrigin.current) return;
    const dx = e.clientX - dragOrigin.current.x;
    const dy = e.clientY - dragOrigin.current.y;
    setPan({ x: dragOrigin.current.panX + dx, y: dragOrigin.current.panY + dy });
  };

  const handlePointerUp = () => {
    setIsDragging(false);
    dragOrigin.current = null;
  };

  const roleStyle = (node: LineageNode) => {
    if (node.role === 'focus') {
      return {
        stroke: '#C42426',
        fill: '#FDF3F2',
        accent: '#C42426',
        tag: 'Selected',
      };
    }
    if (node.role === 'ancestor') {
      return {
        stroke: '#262321',
        fill: '#FFFFFF',
        accent: '#262321',
        tag: `Gen ${node.generationOffset}`,
      };
    }
    if (node.role === 'descendant') {
      return {
        stroke: '#9E3234',
        fill: '#FFFFFF',
        accent: '#9E3234',
        tag: `Gen +${node.generationOffset}`,
      };
    }
    return {
      stroke: '#2B6249',
      fill: '#FFFFFF',
      accent: '#2B6249',
      tag: node.relationshipBasis === 'inferred-shared-parent' ? 'Sibling (inferred)' : 'Sibling',
    };
  };

  return (
    <div className="rounded-2xl border border-[#E7DCD8] bg-[#FBF9F6] overflow-hidden">
      {/* Graph Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 bg-white border-b border-[#EFE6E3]">
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-xs text-[#5E5753]">
          <span className="inline-flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-sm border-2 border-[#C42426] bg-[#FDF3F2]" />
            Selected
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-sm border-2 border-[#262321]" />
            Ancestor
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-sm border-2 border-[#9E3234]" />
            Descendant
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-sm border-2 border-[#2B6249]" />
            Sibling
          </span>
          <span className="hidden sm:inline text-[#8A7F7A]">
            · Solid line: documented · Dashed: inferred
          </span>
        </div>

        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={() => setZoom((z) => Math.max(0.55, Number((z - 0.15).toFixed(2))))}
            aria-label="Zoom out graph"
            className="p-1.5 rounded-lg border border-[#E7DCD8] bg-white hover:bg-[#FDF3F2] text-[#2E2A27] transition-colors"
          >
            <Minus className="w-4 h-4" />
          </button>
          <span className="px-2 text-xs font-mono text-[#5E5753] tabular-nums">
            {Math.round(zoom * 100)}%
          </span>
          <button
            type="button"
            onClick={() => setZoom((z) => Math.min(1.8, Number((z + 0.15).toFixed(2))))}
            aria-label="Zoom in graph"
            className="p-1.5 rounded-lg border border-[#E7DCD8] bg-white hover:bg-[#FDF3F2] text-[#2E2A27] transition-colors"
          >
            <Plus className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={() => {
              setZoom(1);
              setPan({ x: 0, y: 0 });
            }}
            aria-label="Reset graph view"
            className="ml-1 inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-[#E7DCD8] bg-white hover:bg-[#FDF3F2] text-xs font-medium text-[#2E2A27] transition-colors whitespace-nowrap shrink-0"
          >
            <Maximize2 className="w-3.5 h-3.5" aria-hidden="true" />
            <span>Fit</span>
          </button>
        </div>
      </div>

      {/* Interactive SVG Canvas with fine Madhubani kachni stipple background */}
      <div className="relative w-full h-[380px] sm:h-[460px] bg-[#FBF9F6] select-none overflow-hidden">
        <svg
          role="img"
          aria-label={`Interactive lineage graph centered on ${lineage.focusPerson.label}`}
          viewBox={`0 0 ${layout.canvasWidth} ${layout.canvasHeight}`}
          className={`w-full h-full ${isDragging ? 'cursor-grabbing' : 'cursor-grab'}`}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerLeave={handlePointerUp}
        >
          <defs>
            <pattern id="madhubani-kachni-stipple" width="18" height="18" patternUnits="userSpaceOnUse">
              <line
                x1="4"
                y1="5"
                x2="7"
                y2="5"
                stroke="#C9B3AE"
                strokeWidth="0.8"
                strokeOpacity="0.45"
                strokeLinecap="round"
              />
              <line
                x1="12"
                y1="14"
                x2="15"
                y2="14"
                stroke="#C9B3AE"
                strokeWidth="0.8"
                strokeOpacity="0.45"
                strokeLinecap="round"
              />
            </pattern>
          </defs>

          <rect width={layout.canvasWidth} height={layout.canvasHeight} fill="url(#madhubani-kachni-stipple)" />

          <g
            transform={`translate(${pan.x + (layout.canvasWidth * (1 - zoom)) / 2}, ${
              pan.y + (layout.canvasHeight * (1 - zoom)) / 2
            }) scale(${zoom})`}
          >
            {/* Edges */}
            {lineage.edges.map((edge) => {
              const fromPos = layout.positioned.get(edge.from);
              const toPos = layout.positioned.get(edge.to);
              if (!fromPos || !toPos) return null;

              if (edge.type === 'child_of') {
                const x1 = toPos.x + NODE_WIDTH / 2;
                const y1 = toPos.y + NODE_HEIGHT;
                const x2 = fromPos.x + NODE_WIDTH / 2;
                const y2 = fromPos.y;
                const midY = (y1 + y2) / 2;

                return (
                  <path
                    key={`${edge.type}-${edge.from}-${edge.to}`}
                    d={`M ${x1} ${y1} C ${x1} ${midY}, ${x2} ${midY}, ${x2} ${y2}`}
                    fill="none"
                    stroke="#6E6560"
                    strokeWidth="1.5"
                  />
                );
              }

              const x1 = fromPos.x + NODE_WIDTH / 2;
              const y1 = fromPos.y + NODE_HEIGHT / 2;
              const x2 = toPos.x + NODE_WIDTH / 2;
              const y2 = toPos.y + NODE_HEIGHT / 2;
              const arcY = Math.min(y1, y2) - 44;

              return (
                <path
                  key={`${edge.type}-${edge.from}-${edge.to}`}
                  d={`M ${x1} ${y1 - NODE_HEIGHT / 2} Q ${(x1 + x2) / 2} ${arcY}, ${x2} ${
                    y2 - NODE_HEIGHT / 2
                  }`}
                  fill="none"
                  stroke="#2B6249"
                  strokeWidth="1.5"
                  strokeDasharray={edge.basis === 'inferred' ? '5 4' : undefined}
                />
              );
            })}

            {/* Person Nodes */}
            {Array.from(layout.positioned.values()).map(({ node, x, y }) => {
              const style = roleStyle(node);
              const isFocus = node.role === 'focus';
              const displayName =
                node.person.name_roman.length > 21
                  ? `${node.person.name_roman.slice(0, 20)}…`
                  : node.person.name_roman || node.person.name_dev;
              const secondary = node.person.name_dev || node.person.village_roman || '';
              const secondaryTrim =
                secondary.length > 22 ? `${secondary.slice(0, 21)}…` : secondary;

              return (
                <g
                  key={node.person.id}
                  data-node-id={node.person.id}
                  transform={`translate(${x}, ${y})`}
                  role="button"
                  tabIndex={0}
                  aria-label={`Focus lineage on ${node.person.label}, ${style.tag}${
                    node.person.village_roman ? `, village ${node.person.village_roman}` : ''
                  }`}
                  onClick={() => onSelectPerson(node.person.id)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      onSelectPerson(node.person.id);
                    }
                  }}
                  className="cursor-pointer group focus:outline-none"
                >
                  {/* Madhubani kachni double-line outer frame for selected person */}
                  {isFocus && (
                    <rect
                      x={-4}
                      y={-4}
                      width={NODE_WIDTH + 8}
                      height={NODE_HEIGHT + 8}
                      rx={14}
                      fill="none"
                      stroke="#171514"
                      strokeWidth="1"
                      strokeOpacity="0.65"
                    />
                  )}
                  <rect
                    width={NODE_WIDTH}
                    height={NODE_HEIGHT}
                    rx={10}
                    fill={style.fill}
                    stroke={style.stroke}
                    strokeWidth={isFocus ? 2 : 1.3}
                  />
                  <text
                    x={12}
                    y={18}
                    fontSize="10"
                    fontWeight="600"
                    fill={style.accent}
                    fontFamily="Plus Jakarta Sans, sans-serif"
                  >
                    {style.tag}
                  </text>
                  <text
                    x={12}
                    y={38}
                    fontSize="13.5"
                    fontWeight="600"
                    fill="#171514"
                    fontFamily="Plus Jakarta Sans, sans-serif"
                  >
                    {displayName}
                  </text>
                  <text
                    x={12}
                    y={55}
                    fontSize="11"
                    fill="#5E5753"
                    fontFamily="Plus Jakarta Sans, sans-serif"
                  >
                    {secondaryTrim || `ID ${node.person.id}`}
                  </text>
                </g>
              );
            })}
          </g>
        </svg>
      </div>
    </div>
  );
}
