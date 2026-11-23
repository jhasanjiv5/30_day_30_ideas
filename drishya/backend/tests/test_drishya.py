"""Python unit tests for Drishya grounding, chart accuracy, number guard, translation, QA, and privacy."""

from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from backend.app.core import (
    EXACT_QA_REFUSAL,
    ChartSeriesRow,
    ClarificationSource,
    InMemoryRetentionStore,
    MockLLMProvider,
    NarratedSentence,
    answer_question_rrf,
    extract_allowed_numbers,
    filter_uncited_sentences,
    find_ungrounded_numbers,
    get_bundled_fixture_paper,
    process_clarification_sources,
    translate_with_placeholder_guard,
    verify_chart_against_table,
)


class TestDrishyaBackend(unittest.TestCase):
    def setUp(self) -> None:
        self.doc = get_bundled_fixture_paper()
        self.clarifications = process_clarification_sources(
            [
                ClarificationSource(
                    id="c3",
                    term="Benchmarks",
                    tier=3,
                    provider_name="Web Search",
                    title="Blog Benchmark",
                    url="https://example.org/blog",
                    year=2025,
                    relevance_score=0.8,
                    quote="Sparse windows save 70 to 85 percent GPU memory during long sequences in practice.",
                    contradicts_paper=False,
                ),
                ClarificationSource(
                    id="c1",
                    term="Teleconnections",
                    tier=1,
                    provider_name="Crossref",
                    title="Rao et al. 2024",
                    url="https://doi.org/10.1029/2024GL109821",
                    year=2024,
                    relevance_score=0.95,
                    quote=" ".join(["word"] * 32),  # > 25 words; must be truncated
                    contradicts_paper=True,
                ),
            ]
        )

    def test_grounding_drops_uncited_sentence(self) -> None:
        valid = {"doc:p1/sec-intro", "doc:p5/table-1"}
        sentences = [
            NarratedSentence(id="1", text="25 km grids smooth terrain.", citations=["doc:p1/sec-intro"]),
            NarratedSentence(id="2", text="Hallucinated sentence without citation.", citations=[]),
            NarratedSentence(id="3", text="Invalid ref.", citations=["doc:p99/nonexistent"]),
        ]
        kept, dropped = filter_uncited_sentences(sentences, valid)
        self.assertEqual(len(kept), 1)
        self.assertEqual(dropped, 2)

    def test_chart_accuracy_exact_and_mismatch_fails(self) -> None:
        table = self.doc.tables[0]
        exact_rows = [
            ChartSeriesRow(label=str(r["Model"]), values={"RMSE_5d": r["RMSE_5d"], "VRAM_GB": r["VRAM_GB"]})
            for r in table.rows
        ]
        ok, mismatches = verify_chart_against_table(table, "Model", ["RMSE_5d", "VRAM_GB"], exact_rows)
        self.assertTrue(ok)
        self.assertEqual(mismatches, [])

        bad_rows = list(exact_rows)
        bad_rows[0] = ChartSeriesRow(label="ConvLSTM", values={"RMSE_5d": 99.9, "VRAM_GB": 14.2})
        ok_bad, mismatches_bad = verify_chart_against_table(table, "Model", ["RMSE_5d", "VRAM_GB"], bad_rows)
        self.assertFalse(ok_bad)
        self.assertGreater(len(mismatches_bad), 0)

    def test_number_guard_catches_ungrounded_numbers(self) -> None:
        allowed = extract_allowed_numbers(self.doc, self.clarifications)
        self.assertEqual(find_ungrounded_numbers("MonsoonFormer hits 11.4 mm/day.", allowed), [])
        self.assertEqual(find_ungrounded_numbers("MonsoonFormer hits 97.3 mm/day.", allowed), ["97.3"])

    def test_source_tiers_labels_and_quote_limit(self) -> None:
        self.assertEqual(self.clarifications[0].tier, 1)
        self.assertEqual(self.clarifications[0].view_label, "Differing view")
        self.assertLessEqual(len(self.clarifications[0].quote.split()), 25)
        self.assertEqual(self.clarifications[1].tier, 3)
        self.assertEqual(self.clarifications[1].confidence_label, "lower confidence")

    def test_translation_placeholder_guard(self) -> None:
        sample = "MonsoonFormer reaches 11.4 mm/day RMSE and cuts VRAM to 9.6 GB ($\\alpha_{ij}$)."
        for lang in ("hi", "ta", "ur"):
            translated, verified = translate_with_placeholder_guard(sample, lang)
            self.assertTrue(verified)
            self.assertIn("MonsoonFormer", translated)
            self.assertIn("11.4 mm/day", translated)
            self.assertIn("9.6 GB", translated)
            self.assertIn("$\\alpha_{ij}$", translated)

    def test_qa_and_exact_refusal(self) -> None:
        ans = answer_question_rrf("What is MonsoonFormer 5-day RMSE?", self.doc, self.clarifications)
        self.assertTrue(ans["answered"])
        self.assertGreaterEqual(len(ans["sentences"][0]["citations"]), 1)

        refusal = answer_question_rrf("What was the GDP of Brazil in 1994?", self.doc, self.clarifications)
        self.assertFalse(refusal["answered"])
        self.assertEqual(refusal["refusal"], EXACT_QA_REFUSAL)

    def test_privacy_retention_and_log_redaction(self) -> None:
        store = InMemoryRetentionStore()
        now = datetime.now(timezone.utc)
        store.add_document(self.doc, now - timedelta(days=1))
        for log in store.logs:
            self.assertNotIn("escarpments", log.note)
        deleted = store.sweep_expired(now)
        self.assertEqual(deleted, [self.doc.id])
        self.assertEqual(len(store.documents), 0)
        self.assertEqual(len(store.objects), 0)

    def test_provider_interface(self) -> None:
        provider = MockLLMProvider()
        res = provider.generate_json("mock-v1", "test", {"ok": True})
        self.assertEqual(res["provider"], "mock")


if __name__ == "__main__":
    unittest.main()
