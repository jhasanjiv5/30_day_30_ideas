import React from 'react';
import { ArrowRight, GitBranch } from 'lucide-react';
import type { SearchCandidate } from '../types/panji.ts';

interface CandidateCardProps {
  candidate: SearchCandidate;
  isSelected?: boolean;
  onOpenLineage: (personId: string) => void;
}

export function CandidateCard({ candidate, isSelected, onOpenLineage }: CandidateCardProps) {
  const { person, evidence, connections } = candidate;
  const totalRelatives =
    connections.parentCount +
    connections.childCount +
    connections.explicitSiblingCount +
    connections.sharedParentSiblingCount;

  const hasVillage = Boolean(person.village_roman || person.village_dev);

  return (
    <article
      className={`rounded-2xl bg-white border transition-all duration-150 p-5 sm:p-6 ${
        isSelected
          ? 'border-[#C42426] shadow-[0_6px_24px_rgba(196,36,38,0.10)]'
          : 'border-[#E7DCD8] hover:border-[#C9B3AE] shadow-[0_2px_10px_rgba(23,21,20,0.03)]'
      }`}
    >
      <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
        <div className="min-w-0 space-y-2">
          {/* Primary Identity */}
          <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
            <h3 className="font-serif text-2xl font-semibold text-[#171514] leading-snug">
              {person.name_roman || person.name_dev || person.id}
            </h3>
            {person.name_dev && person.name_roman && (
              <span className="text-lg text-[#5E5753] font-normal">{person.name_dev}</span>
            )}
          </div>

          {/* Unboxed Source-Backed Metadata Row */}
          <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1 text-sm text-[#4A433F]">
            <span>
              <span className="text-[#786E69]">Village:</span>{' '}
              {hasVillage ? (
                <strong className="font-medium text-[#171514]">
                  {person.village_roman || person.village_dev}
                  {person.village_dev && person.village_roman ? ` (${person.village_dev})` : ''}
                </strong>
              ) : (
                <span className="italic text-[#8A7F7A]">Not recorded</span>
              )}
            </span>

            {person.titles && (
              <>
                <span aria-hidden="true" className="text-[#D2C3BE]">·</span>
                <span>
                  <span className="text-[#786E69]">Title:</span>{' '}
                  <strong className="font-medium text-[#171514]">{person.titles}</strong>
                </span>
              </>
            )}

            <span aria-hidden="true" className="text-[#D2C3BE]">·</span>
            <span className="font-mono text-xs text-[#5E5753] tabular-nums">
              ID {person.id}
              {person.source_ref ? ` · Ref ${person.source_ref}` : ''}
            </span>
          </div>

          {/* Inferred Mool / Gotra Row */}
          <div className="text-xs sm:text-[13px] text-[#5E5753] flex flex-wrap items-center gap-x-2.5 gap-y-1">
            {person.inferredMool ? (
              <span>
                <span className="text-[#8A7F7A]">Inferred Mool:</span>{' '}
                <span className="font-medium text-[#171514]">
                  {person.inferredMool.name_roman} ({person.inferredMool.name_dev})
                </span>
              </span>
            ) : (
              <span className="text-[#8A7F7A]">Mool: not inferred from recorded village</span>
            )}

            {person.inferredGotras.length > 0 && (
              <>
                <span aria-hidden="true" className="text-[#D2C3BE]">·</span>
                <span>
                  <span className="text-[#8A7F7A]">Inferred Gotra:</span>{' '}
                  <span className="font-medium text-[#171514]">
                    {person.inferredGotras.map((g) => g.name_roman).join(' / ')}
                  </span>
                  {person.inferredGotras.length > 1 && (
                    <span className="text-[#8A7F7A]"> (multiple possible)</span>
                  )}
                </span>
              </>
            )}
          </div>
        </div>

        <div className="flex sm:flex-col items-center sm:items-end justify-between gap-2 shrink-0">
          <button
            type="button"
            onClick={() => onOpenLineage(person.id)}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-[#FDF3F2] hover:bg-[#C42426] text-[#8E181A] hover:text-white border border-[#E7C6C4] hover:border-[#C42426] text-sm font-medium transition-colors whitespace-nowrap shrink-0"
          >
            <GitBranch className="w-4 h-4" aria-hidden="true" />
            <span>Open Lineage</span>
            <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
          </button>

          <span className="text-xs text-[#5E5753] tabular-nums">
            {totalRelatives === 0
              ? 'No recorded relatives'
              : `${connections.parentCount} parent · ${connections.childCount} child · ${
                  connections.explicitSiblingCount + connections.sharedParentSiblingCount
                } sibling`}
          </span>
        </div>
      </div>

      {/* Matching Evidence & Provenance Footer */}
      {(evidence.length > 0 || person.source_file) && (
        <div className="mt-4 pt-3.5 border-t border-[#F2E9E6] flex flex-col gap-1.5 text-xs">
          {evidence.map((ev, idx) => (
            <div key={`${ev.field}-${idx}`} className="flex items-start gap-2 text-[#4A433F]">
              <span
                className={`font-semibold shrink-0 ${
                  ev.field === 'semantic'
                    ? 'text-[#64519A]'
                    : ev.basis === 'source-backed'
                      ? 'text-[#2B6249]'
                      : 'text-[#A31B1D]'
                }`}
              >
                {ev.field === 'semantic'
                  ? 'Semantic match:'
                  : ev.basis === 'source-backed'
                    ? 'Source-backed:'
                    : 'Inferred:'}
              </span>
              <span>{ev.reason}</span>
            </div>
          ))}
          {person.source_file && (
            <div className="text-[#786E69]">
              Corpus file: <span className="font-mono">{person.source_file}</span>
              {person.source_ref ? ` (index ${person.source_ref})` : ''}
            </div>
          )}
        </div>
      )}
    </article>
  );
}
