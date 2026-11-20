import { useState } from 'react';
import { Check, Download, MessageSquare, X } from 'lucide-react';
import type { AuthSession, POC, SignOffDecision } from '../types/domain.ts';
import {
  submitCommentApi,
  submitSignOffApi,
  type ClientAuthHeaders,
} from '../utils/api.ts';
import { downloadSteeringCommitteePdf } from '../utils/pdfExport.ts';
import { CheckStatusLabel } from './StatusIndicator.tsx';

interface SignOffViewProps {
  poc: POC;
  session: AuthSession;
  auth: ClientAuthHeaders;
  onPocUpdated: (poc: POC) => void;
  onExportPdf?: () => void;
}

export function SignOffView({
  poc,
  session,
  auth,
  onPocUpdated,
  onExportPdf,
}: SignOffViewProps) {
  const [notesByReq, setNotesByReq] = useState<Record<string, string>>({});
  const [commentByReq, setCommentByReq] = useState<Record<string, string>>({});
  const [busyReq, setBusyReq] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<string | null>(null);

  const inScopeReqs = poc.requirements.filter((r) => r.in_scope && r.approved_by_engineer);

  const handleDecision = async (reqId: string, decision: SignOffDecision) => {
    setBusyReq(reqId);
    setFeedback(null);
    try {
      const updated = await submitSignOffApi(
        poc.id,
        { requirement_id: reqId, decision, note: notesByReq[reqId] || '' },
        auth
      );
      onPocUpdated(updated);
      setFeedback(`Saved sign-off decision for ${reqId}.`);
    } catch (err) {
      setFeedback(err instanceof Error ? err.message : 'Failed to save sign-off');
    } finally {
      setBusyReq(null);
    }
  };

  const handleComment = async (reqId: string) => {
    const body = (commentByReq[reqId] || '').trim();
    if (!body) return;
    setBusyReq(reqId);
    setFeedback(null);
    try {
      const updated = await submitCommentApi(
        poc.id,
        { requirement_id: reqId, body },
        auth
      );
      onPocUpdated(updated);
      setCommentByReq((prev) => ({ ...prev, [reqId]: '' }));
    } catch (err) {
      setFeedback(err instanceof Error ? err.message : 'Failed to post comment');
    } finally {
      setBusyReq(null);
    }
  };

  return (
    <section aria-labelledby="signoff-heading" className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1
            id="signoff-heading"
            className="text-2xl font-bold tracking-tight text-[#242424] sm:text-3xl"
          >
            Stakeholder Sign-Off &amp; Review Notes
          </h1>
          <p className="mt-1 max-w-2xl text-sm text-[#605E5C]">
            Approve or request changes per deliverable as{' '}
            <strong className="font-semibold text-[#242424]">{session.user_name}</strong>, then
            export the steering-committee PDF summary with full audit trail.
          </p>
        </div>

        <button
          type="button"
          onClick={() => {
            downloadSteeringCommitteePdf(poc);
            onExportPdf?.();
          }}
          className="inline-flex min-h-[40px] items-center gap-2 self-start rounded bg-[#107C41] px-4 py-2 text-sm font-semibold text-white hover:bg-[#0C6233] whitespace-nowrap shrink-0"
        >
          <Download className="h-4 w-4" aria-hidden="true" />
          <span>Export Steering PDF</span>
        </button>
      </div>

      {feedback ? (
        <div
          role="status"
          className="ms-card px-4 py-2.5 text-sm text-[#242424]"
        >
          {feedback}
        </div>
      ) : null}

      <div className="space-y-4">
        {inScopeReqs.map((req) => {
          const check = poc.checks.find((c) => c.requirement_id === req.id);
          const signOffs = poc.sign_offs.filter((s) => s.requirement_id === req.id);
          const comments = poc.comments.filter((c) => c.requirement_id === req.id);

          return (
            <article key={req.id} className="ms-card p-5 space-y-4">
              <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                <div className="space-y-1">
                  <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1">
                    {check ? <CheckStatusLabel status={check.status} /> : null}
                    <span className="font-mono text-xs text-[#605E5C]">{req.id}</span>
                    <span className="text-xs text-[#605E5C]">{req.category}</span>
                  </div>
                  <h2 className="text-base font-semibold text-[#242424]">{req.title}</h2>
                  {check ? (
                    <p className="text-xs text-[#605E5C] tabular-nums">
                      Observed {check.actual_display} vs Target {check.threshold_display}
                    </p>
                  ) : null}
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <button
                    type="button"
                    disabled={busyReq === req.id}
                    onClick={() => handleDecision(req.id, 'approved')}
                    className="inline-flex min-h-[38px] items-center gap-1.5 rounded bg-[#107C41] px-3.5 py-1.5 text-xs font-semibold text-white hover:bg-[#0C6233] disabled:opacity-50 whitespace-nowrap shrink-0"
                  >
                    <Check className="h-3.5 w-3.5" aria-hidden="true" />
                    <span>Approve</span>
                  </button>
                  <button
                    type="button"
                    disabled={busyReq === req.id}
                    onClick={() => handleDecision(req.id, 'changes_requested')}
                    className="inline-flex min-h-[38px] items-center gap-1.5 rounded border border-[#8A8886] bg-white px-3.5 py-1.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1] disabled:opacity-50 whitespace-nowrap shrink-0"
                  >
                    <X className="h-3.5 w-3.5" aria-hidden="true" />
                    <span>Request Change</span>
                  </button>
                </div>
              </div>

              {/* Decision note input */}
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div>
                  <label
                    htmlFor={`signoff-note-${req.id}`}
                    className="block text-xs font-medium text-[#605E5C]"
                  >
                    Optional sign-off rationale
                  </label>
                  <input
                    id={`signoff-note-${req.id}`}
                    type="text"
                    value={notesByReq[req.id] || ''}
                    onChange={(e) =>
                      setNotesByReq((prev) => ({ ...prev, [req.id]: e.target.value }))
                    }
                    placeholder="Add decision note before approving or requesting change"
                    className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] bg-white px-3 text-sm text-[#242424]"
                  />
                </div>

                <div>
                  <label
                    htmlFor={`comment-input-${req.id}`}
                    className="block text-xs font-medium text-[#605E5C]"
                  >
                    Add discussion comment
                  </label>
                  <div className="mt-1 flex gap-2">
                    <input
                      id={`comment-input-${req.id}`}
                      type="text"
                      value={commentByReq[req.id] || ''}
                      onChange={(e) =>
                        setCommentByReq((prev) => ({ ...prev, [req.id]: e.target.value }))
                      }
                      placeholder="Ask a question or record a condition"
                      className="min-h-[38px] flex-1 rounded border border-[#8A8886] bg-white px-3 text-sm text-[#242424]"
                    />
                    <button
                      type="button"
                      disabled={busyReq === req.id}
                      onClick={() => handleComment(req.id)}
                      className="inline-flex min-h-[38px] items-center gap-1.5 rounded border border-[#8A8886] bg-white px-3 py-1.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1] whitespace-nowrap shrink-0"
                    >
                      <MessageSquare className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
                      <span>Comment</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* Existing sign-offs & comments */}
              {(signOffs.length > 0 || comments.length > 0) && (
                <div className="border-t border-[#EDEBE9] pt-3 space-y-2 text-xs text-[#323130]">
                  {signOffs.map((so) => (
                    <div key={so.id} className="flex flex-wrap items-center gap-x-2">
                      <span
                        className={`font-semibold ${
                          so.decision === 'approved' ? 'text-[#107C10]' : 'text-[#A45B00]'
                        }`}
                      >
                        {so.decision === 'approved' ? 'Approved' : 'Changes requested'}
                      </span>
                      <span>by {so.reviewer_name}</span>
                      {so.note ? <span className="text-[#605E5C]">— &ldquo;{so.note}&rdquo;</span> : null}
                    </div>
                  ))}
                  {comments.map((c) => (
                    <div key={c.id} className="text-[#323130]">
                      <span className="font-semibold text-[#242424]">{c.author_name}</span>{' '}
                      <span className="text-[#605E5C]">({c.author_role}):</span> {c.body}
                    </div>
                  ))}
                </div>
              )}
            </article>
          );
        })}
      </div>
    </section>
  );
}
