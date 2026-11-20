import { useState, type ChangeEvent, type FormEvent } from 'react';
import { Upload, X } from 'lucide-react';
import type { POC } from '../types/domain.ts';
import { createPocApi, type ClientAuthHeaders } from '../utils/api.ts';
import { ProviderLogoBadge, TerraformLogo, YamlLogo } from './BrandVisuals.tsx';

interface CreatePocModalProps {
  open: boolean;
  auth: ClientAuthHeaders;
  onClose: () => void;
  onCreated: (poc: POC) => void;
}

const DEFAULT_REQ_SAMPLE = `- Checkout pages respond under 250 ms for 95% of users
- Service availability stays above 99.90%
- Customer data stays inside European Union data centers
- Monthly infrastructure spend stays under $450/mo`;

export function CreatePocModal({
  open,
  auth,
  onClose,
  onCreated,
}: CreatePocModalProps) {
  const [name, setName] = useState('');
  const [businessSummary, setBusinessSummary] = useState('');
  const [projectId, setProjectId] = useState('');
  const [primaryRegion, setPrimaryRegion] = useState('europe-west1');
  const [dataPolicy, setDataPolicy] = useState<'eu_only' | 'global'>('eu_only');
  const [budgetCapUsd, setBudgetCapUsd] = useState(450);
  const [teardownDays, setTeardownDays] = useState(7);
  const [selectedLlmProvider, setSelectedLlmProvider] = useState('none');
  const [terraformStateJson, setTerraformStateJson] = useState('');
  const [tfFileName, setTfFileName] = useState('');
  const [requirementsText, setRequirementsText] = useState(DEFAULT_REQ_SAMPLE);
  const [reqFileName, setReqFileName] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  const handleTfFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setTfFileName(file.name);
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        setTerraformStateJson(reader.result);
      }
    };
    reader.readAsText(file);
  };

  const handleReqFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setReqFileName(file.name);
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        setRequirementsText(reader.result);
      }
    };
    reader.readAsText(file);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const poc = await createPocApi(
        {
          name: name.trim(),
          business_summary: businessSummary.trim(),
          owner_name: 'Priya Nair',
          project_id: projectId.trim(),
          primary_region: primaryRegion,
          data_policy: dataPolicy,
          budget_cap_usd: budgetCapUsd,
          teardown_days: teardownDays,
          selected_llm_provider: selectedLlmProvider,
          terraform_state_json: terraformStateJson || undefined,
          requirements_text: requirementsText,
        },
        auth
      );
      onCreated(poc);
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to create POC');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="create-poc-title"
      className="fixed inset-0 z-50 flex items-center justify-center bg-[#242424]/45 p-4 overflow-y-auto"
    >
      <div className="w-full max-w-2xl rounded border border-[#E1DFDD] bg-white shadow-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-start justify-between gap-4 border-b border-[#E1DFDD] bg-[#F3F2F1] px-6 py-4">
          <div>
            <h2 id="create-poc-title" className="text-lg font-bold text-[#242424]">
              Add or Upload a POC Environment
            </h2>
            <p className="mt-1 text-xs text-[#605E5C]">
              Register a short-lived GCP project manually or upload your Terraform state and
              requirements YAML.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close modal"
            className="inline-flex min-h-[36px] min-w-[36px] items-center justify-center rounded text-[#605E5C] hover:bg-[#E1DFDD] hover:text-[#242424]"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="p-6 space-y-4">
          {error ? (
            <div
              role="alert"
              className="rounded border border-[#C50F1F]/30 bg-[#FDF3F4] p-3 text-xs text-[#C50F1F]"
            >
              {error}
            </div>
          ) : null}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <label htmlFor="new-poc-name" className="block text-xs font-semibold text-[#242424]">
                  POC Name *
                </label>
                <input
                  id="new-poc-name"
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g., Supplier Invoice Portal"
                  className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] px-3 text-sm text-[#242424]"
                />
              </div>

              <div>
                <label
                  htmlFor="new-poc-project"
                  className="block text-xs font-semibold text-[#242424]"
                >
                  GCP Project ID (optional in mock mode)
                </label>
                <input
                  id="new-poc-project"
                  type="text"
                  value={projectId}
                  onChange={(e) => setProjectId(e.target.value)}
                  placeholder="e.g., poc-invoice-eu-01"
                  className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] px-3 font-mono text-xs text-[#242424]"
                />
              </div>
            </div>

            <div>
              <label htmlFor="new-poc-summary" className="block text-xs font-semibold text-[#242424]">
                Plain-Language Business Summary *
              </label>
              <input
                id="new-poc-summary"
                type="text"
                required
                value={businessSummary}
                onChange={(e) => setBusinessSummary(e.target.value)}
                placeholder="Explain what this POC proves for non-technical stakeholders"
                className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] px-3 text-sm text-[#242424]"
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-4">
              <div className="sm:col-span-2">
                <label
                  htmlFor="new-poc-region"
                  className="block text-xs font-semibold text-[#242424]"
                >
                  Primary Region
                </label>
                <select
                  id="new-poc-region"
                  value={primaryRegion}
                  onChange={(e) => setPrimaryRegion(e.target.value)}
                  className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] bg-white px-2.5 text-sm text-[#242424]"
                >
                  <option value="europe-west1">Belgium (europe-west1)</option>
                  <option value="europe-west4">Netherlands (europe-west4)</option>
                  <option value="europe-west3">Frankfurt (europe-west3)</option>
                  <option value="us-central1">Iowa (us-central1)</option>
                </select>
              </div>

              <div>
                <label
                  htmlFor="new-poc-budget"
                  className="block text-xs font-semibold text-[#242424]"
                >
                  Budget Cap ($)
                </label>
                <input
                  id="new-poc-budget"
                  type="number"
                  min={50}
                  value={budgetCapUsd}
                  onChange={(e) => setBudgetCapUsd(Number(e.target.value))}
                  className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] px-3 font-mono text-sm text-[#242424]"
                />
              </div>

              <div>
                <label
                  htmlFor="new-poc-teardown"
                  className="block text-xs font-semibold text-[#242424]"
                >
                  Teardown (days)
                </label>
                <input
                  id="new-poc-teardown"
                  type="number"
                  min={1}
                  max={90}
                  value={teardownDays}
                  onChange={(e) => setTeardownDays(Number(e.target.value))}
                  className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] px-3 font-mono text-sm text-[#242424]"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <label
                  htmlFor="new-poc-policy"
                  className="block text-xs font-semibold text-[#242424]"
                >
                  Data Residency Policy
                </label>
                <select
                  id="new-poc-policy"
                  value={dataPolicy}
                  onChange={(e) => setDataPolicy(e.target.value as 'eu_only' | 'global')}
                  className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] bg-white px-2.5 text-sm text-[#242424]"
                >
                  <option value="eu_only">EU Data Residency Only</option>
                  <option value="global">Global (All Providers Allowed)</option>
                </select>
              </div>

              <div>
                <label
                  htmlFor="new-poc-llm"
                  className="flex items-center gap-1.5 text-xs font-semibold text-[#242424]"
                >
                  <ProviderLogoBadge providerId={selectedLlmProvider} className="h-4 w-4" />
                  <span>Requirements Mapping Mode</span>
                </label>
                <select
                  id="new-poc-llm"
                  value={selectedLlmProvider}
                  onChange={(e) => setSelectedLlmProvider(e.target.value)}
                  className="mt-1 min-h-[38px] w-full rounded border border-[#8A8886] bg-white px-2.5 text-sm text-[#242424]"
                >
                  <option value="none">None (Direct YAML / Manual Parser)</option>
                  <option value="vertex_gemini">Draft with Vertex AI Gemini (EU)</option>
                  <option value="azure_openai">Draft with Azure OpenAI (EU North)</option>
                </select>
              </div>
            </div>

            {/* Optional File Uploads with Visual Format Logos */}
            <div className="grid grid-cols-1 gap-4 rounded border border-[#E1DFDD] bg-[#FAF9F8] p-4 sm:grid-cols-2">
              <div className="flex items-start gap-3">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-white">
                  <TerraformLogo className="h-5 w-5" />
                </div>
                <div>
                  <div className="text-xs font-semibold text-[#242424]">
                    1. Terraform State (Optional)
                  </div>
                  <p className="mt-0.5 text-[11px] text-[#605E5C]">
                    Auto-build the visual Architecture Map.
                  </p>
                  <label className="mt-2 inline-flex min-h-[34px] cursor-pointer items-center gap-1.5 rounded border border-[#8A8886] bg-white px-3 py-1.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1]">
                    <Upload className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
                    <span>{tfFileName || 'Upload .tfstate JSON'}</span>
                    <input
                      type="file"
                      accept=".json,.tfstate"
                      onChange={handleTfFile}
                      className="sr-only"
                    />
                  </label>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded border border-[#E1DFDD] bg-white">
                  <YamlLogo className="h-5 w-5" />
                </div>
                <div>
                  <div className="text-xs font-semibold text-[#242424]">
                    2. Requirements File (Optional)
                  </div>
                  <p className="mt-0.5 text-[11px] text-[#605E5C]">
                    Load <code className="font-mono">.yaml</code> or edit bullets below.
                  </p>
                  <label className="mt-2 inline-flex min-h-[34px] cursor-pointer items-center gap-1.5 rounded border border-[#8A8886] bg-white px-3 py-1.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1]">
                    <Upload className="h-3.5 w-3.5 text-[#107C41]" aria-hidden="true" />
                    <span>{reqFileName || 'Upload YAML / Text'}</span>
                    <input
                      type="file"
                      accept=".yaml,.yml,.txt,.md"
                      onChange={handleReqFile}
                      className="sr-only"
                    />
                  </label>
                </div>
              </div>
            </div>

            <div>
              <label htmlFor="new-poc-reqs" className="block text-xs font-semibold text-[#242424]">
                Initial Requirements (YAML or plain-language bullets)
              </label>
              <textarea
                id="new-poc-reqs"
                rows={4}
                value={requirementsText}
                onChange={(e) => setRequirementsText(e.target.value)}
                className="mt-1 w-full rounded border border-[#8A8886] p-2.5 font-mono text-xs text-[#242424]"
              />
            </div>

            <div className="flex items-center justify-end gap-3 border-t border-[#EDEBE9] pt-4">
              <button
                type="button"
                onClick={onClose}
                className="min-h-[38px] rounded border border-[#8A8886] bg-white px-4 py-1.5 text-xs font-medium text-[#242424] hover:bg-[#F3F2F1]"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={submitting || !name.trim() || !businessSummary.trim()}
                className="min-h-[38px] rounded bg-[#107C41] px-5 py-1.5 text-xs font-semibold text-white hover:bg-[#0C6233] disabled:opacity-50"
              >
                {submitting ? 'Creating POC...' : 'Create POC Environment'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
