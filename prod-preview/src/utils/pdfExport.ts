import { jsPDF } from 'jspdf';
import type { POC } from '../types/domain.ts';

export function buildSteeringCommitteePdf(poc: POC): jsPDF {
  const doc = new jsPDF({ unit: 'pt', format: 'a4' });
  const margin = 44;
  const pageWidth = doc.internal.pageSize.getWidth();
  const maxWidth = pageWidth - margin * 2;
  let y = 52;

  const ensureSpace = (needed: number) => {
    if (y + needed > 780) {
      doc.addPage();
      y = 52;
    }
  };

  // Header
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(18);
  doc.text('Prod Preview — Steering Committee Summary', margin, y);
  y += 22;

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.setTextColor(71, 85, 105);
  doc.text(
    `POC: ${poc.name}  |  Region: ${poc.environment.region_display}  |  Status: ${poc.environment.lifecycle_state.toUpperCase()} (${poc.environment.days_until_teardown}d to teardown)`,
    margin,
    y
  );
  y += 16;
  doc.text(
    `Generated: ${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC  |  Data Policy: ${poc.data_policy === 'eu_only' ? 'EU Data Residency Only' : 'Global'}`,
    margin,
    y
  );
  y += 20;

  // Business Summary
  doc.setTextColor(15, 23, 42);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.text('1. Executive Overview', margin, y);
  y += 15;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  const summaryLines = doc.splitTextToSize(poc.business_summary, maxWidth);
  doc.text(summaryLines, margin, y);
  y += summaryLines.length * 13 + 14;

  // Requirements Scorecard
  ensureSpace(80);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.text('2. In-Scope Requirements Scorecard', margin, y);
  y += 16;

  const inScope = poc.requirements.filter((r) => r.in_scope && r.approved_by_engineer);
  for (const req of inScope) {
    const check = poc.checks.find((c) => c.requirement_id === req.id);
    const signOff = poc.sign_offs.find((s) => s.requirement_id === req.id);
    ensureSpace(56);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(10);
    const statusLabel = check
      ? check.status === 'pass'
        ? '[PASS]'
        : check.status === 'warn'
          ? '[WARN]'
          : '[FAIL]'
      : '[PENDING]';
    const titleLines = doc.splitTextToSize(`${statusLabel} ${req.id}: ${req.title}`, maxWidth);
    doc.text(titleLines, margin, y);
    y += titleLines.length * 12;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(71, 85, 105);
    const detailLine = check
      ? `Observed: ${check.actual_display} (Target: ${check.threshold_display}) | Type: ${check.measured_or_projected.toUpperCase()} | Sign-off: ${signOff ? `${signOff.decision} by ${signOff.reviewer_name}` : 'pending'}`
      : `Target: ${req.threshold} | Sign-off: pending`;
    const dLines = doc.splitTextToSize(detailLine, maxWidth - 12);
    doc.text(dLines, margin + 12, y);
    y += dLines.length * 11 + 8;
    doc.setTextColor(15, 23, 42);
  }

  // Out of Scope
  const outOfScope = poc.requirements.filter((r) => !r.in_scope && r.approved_by_engineer);
  if (outOfScope.length > 0) {
    ensureSpace(50);
    y += 6;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text('3. Explicitly Out of Scope', margin, y);
    y += 15;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    for (const req of outOfScope) {
      ensureSpace(24);
      const lines = doc.splitTextToSize(`- ${req.id}: ${req.title} (${req.threshold})`, maxWidth);
      doc.text(lines, margin + 8, y);
      y += lines.length * 12;
    }
    y += 10;
  }

  // Comments
  if (poc.comments.length > 0) {
    ensureSpace(60);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text('4. Stakeholder Review Notes', margin, y);
    y += 15;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    for (const c of poc.comments) {
      ensureSpace(32);
      const cLines = doc.splitTextToSize(
        `[${c.requirement_id}] ${c.author_name} (${c.author_role}): ${c.body}`,
        maxWidth
      );
      doc.text(cLines, margin + 8, y);
      y += cLines.length * 11 + 5;
    }
    y += 10;
  }

  // Appendix: LLM Audit Log (never contains any API keys)
  ensureSpace(70);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.text('Appendix A: LLM Mapping Audit Log', margin, y);
  y += 15;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  if (poc.audit_log.length === 0) {
    doc.text('No LLM-assisted mappings recorded (manual mapping only).', margin, y);
  } else {
    for (const a of poc.audit_log) {
      ensureSpace(34);
      const line = `${a.created_at.slice(0, 16)} | Requested: ${a.requested_provider} -> Answered: ${a.answered_by_provider} (${a.model}) | Prompt: ${a.prompt_version} | Latency: ${a.latency_ms}ms | Tokens: ${a.input_tokens}/${a.output_tokens} | Est. Cost: $${a.estimated_cost_usd.toFixed(5)} | Approved: ${a.approved ? 'Yes' : 'Pending'}`;
      const lines = doc.splitTextToSize(line, maxWidth);
      doc.text(lines, margin, y);
      y += lines.length * 11 + 6;
    }
  }

  return doc;
}

export function downloadSteeringCommitteePdf(poc: POC): void {
  const doc = buildSteeringCommitteePdf(poc);
  doc.save(`${poc.id}-steering-summary.pdf`);
}
