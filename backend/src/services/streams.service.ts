import type { SupabaseClient } from '@supabase/supabase-js';

import type { RequestPrincipal, StreamLinkRow } from '../domain/types';
import { ForbiddenError } from '../lib/errors';
import { ensureSuccess, optionalData, requiredData } from '../lib/supabase-result';

export interface StreamLinkInput {
  stream_title: string;
  competition_name?: string | null;
  played_on: string;
  stream_url: string;
  stream_status: 'live' | 'ended';
  stream_ended_at?: string | null;
  provider?: string | null;
  result?: string | null;
}

function normalizeText(value: string | null | undefined): string | null {
  const normalized = value?.trim() ?? '';
  return normalized.length > 0 ? normalized : null;
}

function normalizeDateOnly(value: string): string {
  return value.trim().slice(0, 10);
}

export class StreamsService {
  constructor(private readonly db: SupabaseClient) {}

  async listStreams(): Promise<StreamLinkRow[]> {
    const response = await this.db
      .from('stream_links')
      .select('*')
      .order('created_at', { ascending: false });

    const rows = (optionalData(response) as StreamLinkRow[] | null) ?? [];

    return [...rows].sort((left, right) => {
      if (left.stream_status !== right.stream_status) {
        return left.stream_status === 'live' ? -1 : 1;
      }

      const leftReference = left.stream_ended_at ?? left.played_on;
      const rightReference = right.stream_ended_at ?? right.played_on;
      return new Date(rightReference).getTime() - new Date(leftReference).getTime();
    });
  }

  async createStream(input: StreamLinkInput, principal: RequestPrincipal): Promise<StreamLinkRow> {
    this.ensureCanManageStreams(principal);

    const response = await this.db
      .from('stream_links')
      .insert(this.buildPayload(input))
      .select('*')
      .single();

    return requiredData(response) as StreamLinkRow;
  }

  async updateStream(
    streamId: string | number,
    input: StreamLinkInput,
    principal: RequestPrincipal,
  ): Promise<StreamLinkRow> {
    this.ensureCanManageStreams(principal);

    const response = await this.db
      .from('stream_links')
      .update(this.buildPayload(input))
      .eq('id', streamId)
      .select('*')
      .single();

    return requiredData(response) as StreamLinkRow;
  }

  async deleteStream(streamId: string | number, principal: RequestPrincipal): Promise<void> {
    this.ensureCanManageStreams(principal);
    const response = await this.db.from('stream_links').delete().eq('id', streamId);
    ensureSuccess(response);
  }

  async deleteAllStreams(principal: RequestPrincipal): Promise<void> {
    this.ensureCanManageStreams(principal);

    const response = await this.db.from('stream_links').select('id');
    const rows = optionalData(response) as Array<{ id: number | string }> | null;
    const ids = (rows ?? []).map((row) => row.id).filter((id) => id != null);

    if (ids.length === 0) {
      return;
    }

    const deleteResponse = await this.db.from('stream_links').delete().in('id', ids);
    ensureSuccess(deleteResponse);
  }

  async deleteStreamsForDay(playedOn: string, principal: RequestPrincipal): Promise<void> {
    this.ensureCanManageStreams(principal);

    const response = await this.db
      .from('stream_links')
      .delete()
      .eq('played_on', normalizeDateOnly(playedOn));

    ensureSuccess(response);
  }

  private ensureCanManageStreams(principal: RequestPrincipal): void {
    if (!principal.canManageStreams) {
      throw new ForbiddenError('Non hai i permessi per gestire le live');
    }
  }

  private buildPayload(input: StreamLinkInput) {
    return {
      stream_title: input.stream_title.trim(),
      competition_name: normalizeText(input.competition_name),
      played_on: normalizeDateOnly(input.played_on),
      stream_url: input.stream_url.trim(),
      stream_status: input.stream_status,
      stream_ended_at: normalizeText(input.stream_ended_at),
      provider: normalizeText(input.provider),
      result: normalizeText(input.result),
    };
  }
}
