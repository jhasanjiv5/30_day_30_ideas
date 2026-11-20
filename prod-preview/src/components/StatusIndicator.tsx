import {
  AlertTriangle,
  CheckCircle2,
  Clock,
  Compass,
  PowerOff,
  Ruler,
  TrendingUp,
  XCircle,
} from 'lucide-react';
import type {
  CheckStatus,
  EnvironmentLifecycleState,
  MeasurementKind,
} from '../types/domain.ts';

export function CheckStatusLabel({ status }: { status: CheckStatus }) {
  if (status === 'pass') {
    return (
      <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#107C10] whitespace-nowrap">
        <CheckCircle2 className="h-4 w-4 shrink-0" aria-hidden="true" />
        <span>Passing</span>
      </span>
    );
  }
  if (status === 'warn') {
    return (
      <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#A45B00] whitespace-nowrap">
        <AlertTriangle className="h-4 w-4 shrink-0" aria-hidden="true" />
        <span>Needs attention</span>
      </span>
    );
  }
  return (
    <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#C50F1F] whitespace-nowrap">
      <XCircle className="h-4 w-4 shrink-0" aria-hidden="true" />
      <span>Failing</span>
    </span>
  );
}

export function MeasurementKindLabel({ kind }: { kind: MeasurementKind }) {
  if (kind === 'measured') {
    return (
      <span className="inline-flex items-center gap-1 text-xs font-medium text-[#323130] whitespace-nowrap">
        <Ruler className="h-3.5 w-3.5 text-[#107C41] shrink-0" aria-hidden="true" />
        <span>Measured</span>
      </span>
    );
  }
  return (
    <span className="inline-flex items-center gap-1 text-xs font-medium text-[#323130] whitespace-nowrap">
      <TrendingUp className="h-3.5 w-3.5 text-[#A45B00] shrink-0" aria-hidden="true" />
      <span>Projected</span>
    </span>
  );
}

export function LifecycleStateLabel({ state }: { state: EnvironmentLifecycleState }) {
  if (state === 'live') {
    return (
      <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#107C10] whitespace-nowrap">
        <CheckCircle2 className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
        <span>Live</span>
      </span>
    );
  }
  if (state === 'expiring') {
    return (
      <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#A45B00] whitespace-nowrap">
        <Clock className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
        <span>Expiring soon</span>
      </span>
    );
  }
  if (state === 'provisioning') {
    return (
      <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#0F6CBD] whitespace-nowrap">
        <Compass className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
        <span>Provisioning</span>
      </span>
    );
  }
  return (
    <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#605E5C] whitespace-nowrap">
      <PowerOff className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
      <span>Torn down</span>
    </span>
  );
}
