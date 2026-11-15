import React from 'react';
import { ArrowRight, BookOpen, GitBranch, GitCompareArrows, GitFork, Search } from 'lucide-react';
import { MadhubaniBorderStrip } from './MadhubaniMotifs.tsx';

interface UsageGuideProps {
  onTrySearch: (query: string) => void;
  onTryRelationshipSample: () => void;
  onOpenMoolBrowser: () => void;
  onOpenTreeCoverage: () => void;
}

export function UsageGuide({
  onTrySearch,
  onTryRelationshipSample,
  onOpenMoolBrowser,
  onOpenTreeCoverage,
}: UsageGuideProps) {
  return (
    <section
      aria-label="How to use the Panji Search Guide"
      className="relative overflow-hidden rounded-3xl bg-white border border-[#E7DCD8] shadow-[0_10px_32px_rgba(23,21,20,0.04)]"
    >
      <MadhubaniBorderStrip />

      <div className="p-5 sm:p-8 space-y-7">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-3">
          <div className="space-y-1">
            <div className="inline-flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider text-[#C42426]">
              <BookOpen className="w-3.5 h-3.5" aria-hidden="true" />
              <span>How This Search Guide Works</span>
            </div>
            <h2 className="font-serif text-2xl sm:text-3xl font-semibold text-[#171514]">
              An example walkthrough &amp; ways it can help you
            </h2>
          </div>
          <p className="text-xs sm:text-sm text-[#5E5753] max-w-md">
            Every result clearly separates facts written in the 2009 Panji extract from links
            inferred through village or shared-parent matching.
          </p>
        </div>

        {/* Step-by-Step Illustrated Example */}
        <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4 sm:p-6 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div className="text-xs font-semibold uppercase tracking-wider text-[#5E5753]">
              Illustrative Example: Tracing an ancestor from memory
            </div>
            <button
              type="button"
              onClick={() => onTrySearch('I am looking for Bhagiratha from Darihara')}
              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-[#C42426] hover:bg-[#A31B1D] text-white text-xs font-medium transition-colors self-start sm:self-auto whitespace-nowrap"
            >
              <span>Run this example</span>
              <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5 text-xs sm:text-[13px]">
            <div className="rounded-xl bg-white border border-[#E7DCD8] p-4 space-y-1.5">
              <div className="font-mono text-[11px] font-semibold text-[#C42426]">STEP 1 · ASK NATURALLY</div>
              <div className="font-medium text-[#171514]">
                &ldquo;I am looking for Bhagiratha from Darihara&rdquo;
              </div>
              <p className="text-[#5E5753] leading-relaxed">
                The search engine extracts the name <strong>Bhagiratha</strong> and village{' '}
                <strong>Darihara</strong>, matching across Roman spellings (with or without accent
                marks) and Devanagari (<span className="font-devanagari">भगीरथ</span>).
              </p>
            </div>

            <div className="rounded-xl bg-white border border-[#E7DCD8] p-4 space-y-1.5">
              <div className="font-mono text-[11px] font-semibold text-[#2B6249]">STEP 2 · CHECK EVIDENCE</div>
              <div className="font-medium text-[#171514]">
                bhagīratha · dariharā (Ref 96/09)
              </div>
              <p className="text-[#5E5753] leading-relaxed">
                Name and village appear as <strong className="text-[#2B6249]">Source-backed</strong>{' '}
                facts, while mool <em>dariharā</em> and gotra <em>kāśyapa</em> are flagged honestly
                as <strong className="text-[#A31B1D]">Inferred</strong> from the village name.
              </p>
            </div>

            <div className="rounded-xl bg-white border border-[#E7DCD8] p-4 space-y-1.5">
              <div className="font-mono text-[11px] font-semibold text-[#171514]">STEP 3 · EXPLORE LINEAGE</div>
              <div className="font-medium text-[#171514]">
                Inspect parents, children &amp; AI summary
              </div>
              <p className="text-[#5E5753] leading-relaxed">
                Open the interactive tree and generation list to walk upward or downward, or ask the
                grounded assistant to summarize what is documented—and what is missing.
              </p>
            </div>
          </div>

          <div className="rounded-2xl bg-[#F7F3FB] border border-[#E1D8EE] p-4 sm:p-5 space-y-3">
            <div>
              <div className="text-xs font-semibold uppercase tracking-wider text-[#64519A]">
                Describe the family context
              </div>
              <p className="mt-1 text-xs sm:text-[13px] text-[#5E5753] leading-relaxed">
                Semantic search compares the full recorded profile—including village, titles,
                inferred gotra context, and relatives. Exact names and villages remain strong ranking
                signals.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {[
                'Find profiles similar to Bhagiratha from Darihara',
                'Show ancestors with recorded titles and family links',
                'Look for people connected to Arjuna of Pali',
              ].map((sample) => (
                <button
                  key={sample}
                  type="button"
                  onClick={() => onTrySearch(sample)}
                  className="rounded-lg border border-[#D8CBE8] bg-white px-3 py-2 text-left text-xs font-medium text-[#51416F] transition-colors hover:border-[#64519A]"
                >
                  {sample}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* 4 Purpose Cards */}
        <div className="space-y-3">
          <div className="text-xs font-semibold uppercase tracking-wider text-[#5E5753]">
            How this tool can help you
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4 sm:p-5 flex flex-col justify-between gap-3">
              <div className="space-y-1.5">
                <div className="inline-flex items-center gap-2 font-serif text-lg font-semibold text-[#171514]">
                  <Search className="w-4 h-4 text-[#C42426]" aria-hidden="true" />
                  <span>Locate a Documented Ancestor</span>
                </div>
                <p className="text-xs sm:text-[13px] text-[#5E5753] leading-relaxed">
                  Useful when you know an ancestor&apos;s name, honorific title (such as{' '}
                  <em>kavirāja</em>), Devanagari spelling, or ancestral village and want matching
                  records with citations.
                </p>
              </div>
              <button
                type="button"
                onClick={() => onTrySearch('Arjuna of Pali, Vatsa gotra')}
                className="inline-flex items-center gap-1.5 text-xs font-medium text-[#C42426] hover:underline self-start"
              >
                <span>Try &ldquo;Arjuna of Pali, Vatsa gotra&rdquo;</span>
                <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
              </button>
            </div>

            <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4 sm:p-5 flex flex-col justify-between gap-3">
              <div className="space-y-1.5">
                <div className="inline-flex items-center gap-2 font-serif text-lg font-semibold text-[#171514]">
                  <GitCompareArrows className="w-4 h-4 text-[#C42426]" aria-hidden="true" />
                  <span>Check How Two People Connect</span>
                </div>
                <p className="text-xs sm:text-[13px] text-[#5E5753] leading-relaxed">
                  Useful for family verification: trace the shortest documented chain of parent,
                  child, and sibling records linking two individuals, plus any shared ancestor.
                </p>
              </div>
              <button
                type="button"
                onClick={onTryRelationshipSample}
                className="inline-flex items-center gap-1.5 text-xs font-medium text-[#C42426] hover:underline self-start"
              >
                <span>Try sample path: Arjuna ↔ Lākhū</span>
                <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
              </button>
            </div>

            <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4 sm:p-5 flex flex-col justify-between gap-3">
              <div className="space-y-1.5">
                <div className="inline-flex items-center gap-2 font-serif text-lg font-semibold text-[#171514]">
                  <GitFork className="w-4 h-4 text-[#C42426]" aria-hidden="true" />
                  <span>Disambiguate Mools &amp; Gotras</span>
                </div>
                <p className="text-xs sm:text-[13px] text-[#5E5753] leading-relaxed">
                  Useful when a mool name appears under more than one gotra. Browse all 20
                  canonical gotras and highlight cross-gotra mools before filtering records.
                </p>
              </div>
              <button
                type="button"
                onClick={onOpenMoolBrowser}
                className="inline-flex items-center gap-1.5 text-xs font-medium text-[#C42426] hover:underline self-start"
              >
                <span>Open Mools &amp; Gotras directory</span>
                <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
              </button>
            </div>

            <div className="rounded-2xl bg-[#FBF9F6] border border-[#E7DCD8] p-4 sm:p-5 flex flex-col justify-between gap-3">
              <div className="space-y-1.5">
                <div className="inline-flex items-center gap-2 font-serif text-lg font-semibold text-[#171514]">
                  <GitBranch className="w-4 h-4 text-[#C42426]" aria-hidden="true" />
                  <span>Browse Earliest Family Roots</span>
                </div>
                <p className="text-xs sm:text-[13px] text-[#5E5753] leading-relaxed">
                  Useful when exploring broader branches: view earliest recorded patriarchs ranked
                  by descendant count and generation depth, and open any branch directly.
                </p>
              </div>
              <button
                type="button"
                onClick={onOpenTreeCoverage}
                className="inline-flex items-center gap-1.5 text-xs font-medium text-[#C42426] hover:underline self-start"
              >
                <span>Explore documented family trees</span>
                <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
