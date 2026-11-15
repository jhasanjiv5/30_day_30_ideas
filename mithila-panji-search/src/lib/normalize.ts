/**
 * Text normalization and IAST-to-ASCII folding helpers.
 *
 * Scope & honesty note:
 * - Supports Devanagari exact/substring normalization (NFC, punctuation cleanup).
 * - Supports IAST diacritic folding (ā->a, ś/ṣ->s, ṇ/ṅ/ñ->n, ṭ/ḍ->t/d, ṃ/ṁ->m, ṛ->r, etc.)
 *   plus common ad-hoc Roman spelling normalization (sh->s, aa->a, ee->i, oo->u, jha/zhaa variants).
 * - Does NOT claim phonetic Devanagari-to-Latin cross-script transliteration for arbitrary
 *   unindexed terms; cross-script queries rely on the corpus having both Devanagari and Roman fields.
 */

const IAST_SPECIAL_MAP: Record<string, string> = {
  ś: 's',
  ṣ: 's',
  ṛ: 'r',
  ṝ: 'r',
  ḷ: 'l',
  ḹ: 'l',
  ṇ: 'n',
  ṅ: 'n',
  ñ: 'n',
  ṭ: 't',
  ḍ: 'd',
  ṃ: 'm',
  ṁ: 'm',
  ḥ: 'h',
  r̤: 'r',
  d̤: 'd',
  '~': '',
};

export function normalizeUnicode(input: string): string {
  return (input || '').normalize('NFC').trim().toLowerCase();
}

export function foldIastToAscii(input: string): string {
  if (!input) return '';
  let text = input.normalize('NFD').toLowerCase();
  // Remove combining diacritical marks (macrons, underdots, overdots, acute, etc.)
  text = text.replace(/[\u0300-\u036f]/g, '');
  // Replace any precomposed characters that NFD didn't split
  text = text
    .split('')
    .map((ch) => IAST_SPECIAL_MAP[ch] ?? ch)
    .join('');
  // Normalize ad-hoc tilde nasalization used in upstream (e.g., belau~ca)
  text = text.replace(/~/g, 'n');
  // Normalize whitespace and punctuation
  text = text.replace(/[.,/#!$%^&*;:{}=\-_`~()'"?]+/g, ' ').replace(/\s+/g, ' ').trim();
  return text;
}

/**
 * Normalizes common English/ad-hoc Roman spelling variants so queries like
 * "Shandilya", "Kashyapa", "Shubhankar", "Sarisava" match "śāṇḍilya", "kāśyapa",
 * "śubhaṃkara", "sarisaba".
 */
export function phoneticRomanKey(input: string): string {
  let folded = foldIastToAscii(input);
  if (!folded) return '';
  folded = folded
    .replace(/sh/g, 's')
    .replace(/aa/g, 'a')
    .replace(/ee/g, 'i')
    .replace(/oo/g, 'u')
    .replace(/ph/g, 'f')
    .replace(/w/g, 'v')
    .replace(/z/g, 'jh')
    .replace(/mn/g, 'm')
    .replace(/nk/g, 'mk')
    .replace(/ng/g, 'mg');
  return folded;
}

export function containsDevanagari(input: string): boolean {
  return /[\u0900-\u097F]/.test(input);
}

export function normalizeDevanagari(input: string): string {
  return (input || '')
    .normalize('NFC')
    .replace(/[।॥.,/#!$%^&*;:{}=\-_`~()'"?]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function tokenizeSearchText(input: string): string[] {
  const normalized = containsDevanagari(input)
    ? normalizeDevanagari(input)
    : foldIastToAscii(input);
  if (!normalized) return [];
  return normalized.split(' ').filter(Boolean);
}
