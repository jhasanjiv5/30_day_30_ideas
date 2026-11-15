import type {
  AiExplanationPayload,
  LineageGraph,
  SearchAnswerPayload,
  SearchCandidate,
  SearchFilters,
} from '../types/panji.ts';

export function buildDeterministicSearchAnswer(
  query: string,
  candidates: SearchCandidate[],
  totalMatches: number,
  appliedFilters: SearchFilters = {}
): SearchAnswerPayload {
  const cleanQuery = query.trim();

  if (totalMatches === 0 || candidates.length === 0) {
    const filterNotes = [
      appliedFilters.village ? `village "${appliedFilters.village}"` : '',
      appliedFilters.mool ? `mool "${appliedFilters.mool}"` : '',
      appliedFilters.gotra ? `gotra "${appliedFilters.gotra}"` : '',
    ].filter(Boolean);

    return {
      mode: 'deterministic',
      text: `No documented records in this 2009 Mithila-Panji extract matched ${
        cleanQuery ? `"${cleanQuery}"` : 'your current filters'
      }${filterNotes.length > 0 ? ` (${filterNotes.join(', ')})` : ''}. Because the archive covers 1,888 digitized entries rather than every family, try a shorter given name, alternate spelling, or Devanagari script.`,
      citedRecords: [],
    };
  }

  const top = candidates[0];
  const p = top.person;
  const displayName =
    p.name_roman && p.name_dev ? `${p.name_roman} (${p.name_dev})` : p.label;

  const sentence1 =
    totalMatches === 1
      ? `One matching record was found: ${displayName}${
          p.village_roman || p.village_dev
            ? `, recorded in ${p.village_roman || p.village_dev}`
            : ''
        }${p.source_ref ? ` (ref ${p.source_ref})` : ''}.`
      : `${totalMatches} matching records were found; the closest match is ${displayName}${
          p.village_roman || p.village_dev
            ? ` from ${p.village_roman || p.village_dev}`
            : ''
        }${p.source_ref ? ` (ref ${p.source_ref})` : ''}.`;

  const lineageParts: string[] = [];
  if (top.connections.parentLabels && top.connections.parentLabels.length > 0) {
    lineageParts.push(`parent: ${top.connections.parentLabels.slice(0, 2).join(', ')}`);
  } else if (top.connections.parentCount > 0) {
    lineageParts.push(`${top.connections.parentCount} recorded parent(s)`);
  }
  if (top.connections.childLabels && top.connections.childLabels.length > 0) {
    lineageParts.push(`child(ren): ${top.connections.childLabels.slice(0, 3).join(', ')}`);
  } else if (top.connections.childCount > 0) {
    lineageParts.push(`${top.connections.childCount} recorded child(ren)`);
  }

  const inferredParts: string[] = [];
  if (p.inferredMool) {
    inferredParts.push(`inferred mool ${p.inferredMool.name_roman}`);
  }
  if (p.inferredGotras.length > 0) {
    inferredParts.push(
      `inferred gotra ${p.inferredGotras.map((g) => g.name_roman).join(' / ')}`
    );
  }

  const sentence2Parts: string[] = [];
  if (lineageParts.length > 0) {
    sentence2Parts.push(`Documented links include ${lineageParts.join(' and ')}`);
  }
  if (inferredParts.length > 0) {
    sentence2Parts.push(`with ${inferredParts.join(' and ')}`);
  }

  const sentence2 =
    sentence2Parts.length > 0
      ? `${sentence2Parts.join(', ')}.`
      : 'No parent, child, or inferred gotra links are recorded on the top entry; inspect the matching records below for source details.';

  const citedRecords = candidates.slice(0, 3).map((c) => ({
    id: c.person.id,
    label: c.person.label,
    source_ref: c.person.source_ref,
  }));

  return {
    mode: 'deterministic',
    text: `${sentence1} ${sentence2}`,
    citedRecords,
  };
}

export function buildDeterministicExplanationFromLineage(
  lineage: LineageGraph,
  query?: string
): AiExplanationPayload {
  const p = lineage.focusPerson;
  const parents = lineage.nodes.filter((n) => n.generationOffset === -1);
  const children = lineage.nodes.filter((n) => n.generationOffset === 1);
  const explicitSiblings = lineage.nodes.filter(
    (n) => n.role === 'sibling' && n.relationshipBasis === 'source-backed'
  );
  const inferredSiblings = lineage.nodes.filter(
    (n) => n.role === 'sibling' && n.relationshipBasis === 'inferred-shared-parent'
  );

  const sourceBackedFacts: string[] = [];
  sourceBackedFacts.push(
    `Recorded name: ${p.name_roman || 'not romanized'}${p.name_dev ? ` (${p.name_dev})` : ''} [record ${p.id}].`
  );
  if (p.village_roman || p.village_dev) {
    sourceBackedFacts.push(
      `Recorded village: ${p.village_roman || p.village_dev}${p.village_dev && p.village_roman ? ` (${p.village_dev})` : ''}.`
    );
  }
  if (p.titles) {
    sourceBackedFacts.push(`Recorded title/honorific: ${p.titles}.`);
  }
  if (p.source_ref || p.source_file) {
    sourceBackedFacts.push(
      `Source provenance: ${p.source_file || '2009 Panji extract'}${p.source_ref ? `, ref ${p.source_ref}` : ''}.`
    );
  }
  if (parents.length > 0) {
    sourceBackedFacts.push(
      `Documented parent link(s): ${parents.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
    );
  }
  if (children.length > 0) {
    sourceBackedFacts.push(
      `Documented child link(s): ${children.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
    );
  }
  if (explicitSiblings.length > 0) {
    sourceBackedFacts.push(
      `Explicitly documented sibling(s): ${explicitSiblings.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
    );
  }

  const inferredOrUncertain: string[] = [];
  if (p.inferredMool) {
    inferredOrUncertain.push(
      `Inferred mool "${p.inferredMool.name_roman}" (${p.inferredMool.name_dev}) is derived via village-name matching ("${p.inferredMool.matchedTerm}"), not a direct OF_MOOL attestation.`
    );
  }
  if (p.inferredGotras.length > 0) {
    inferredOrUncertain.push(
      `Inferred gotra(s): ${p.inferredGotras.map((g) => `${g.name_roman} (${g.name_dev})`).join(', ')} via the mool directory.${p.inferredGotras.length > 1 ? ' Multiple gotras share this mool, so family confirmation is needed.' : ''}`
    );
  }
  if (inferredSiblings.length > 0) {
    inferredOrUncertain.push(
      `Possible sibling(s) sharing a documented parent link: ${inferredSiblings.map((n) => `${n.person.label} (${n.person.id})`).join(', ')}.`
    );
  }

  const gapsAndLimitations: string[] = [...lineage.notes];
  if (!p.source_ref) {
    gapsAndLimitations.push('No granular page/index reference (source_ref) is attached to this entry.');
  }
  gapsAndLimitations.push(
    'This 2009 Panji extract contains digitized historical records from Thakur, Jha & Jha (2009) and is not a complete generational atlas.'
  );

  const ancestorDepth = lineage.ancestorChainToOldest.length - 1;
  const descendantNodes = lineage.nodes.filter((n) => n.role === 'descendant').length;
  const summaryParts = [
    `Deterministic record summary for ${p.label}${query ? ` (for query "${query}")` : ''}:`,
    p.village_roman || p.village_dev
      ? `Recorded in village ${p.village_roman || p.village_dev}.`
      : 'No village is recorded on this entry.',
    ancestorDepth > 0
      ? `Traces ${ancestorDepth} generation${ancestorDepth === 1 ? '' : 's'} upward to ${lineage.ancestorChainToOldest[0].label}.`
      : 'No documented parent chain exists above this record in the current dataset.',
    descendantNodes > 0
      ? `${descendantNodes} documented descendant record${descendantNodes === 1 ? '' : 's'} appear below this person.`
      : 'No documented descendants appear below this person.',
  ];

  const citedRecords = [
    { id: p.id, label: p.label, source_ref: p.source_ref },
    ...parents.map((n) => ({
      id: n.person.id,
      label: n.person.label,
      source_ref: n.person.source_ref,
    })),
    ...children.map((n) => ({
      id: n.person.id,
      label: n.person.label,
      source_ref: n.person.source_ref,
    })),
  ].slice(0, 10);

  return {
    mode: 'deterministic',
    personId: p.id,
    summary: summaryParts.join(' '),
    sourceBackedFacts,
    inferredOrUncertain,
    gapsAndLimitations,
    citedRecords,
  };
}
