import type { SupabaseClient } from '@supabase/supabase-js';

import type { MembershipRow, TeamRole } from '../domain/types';
import { optionalData, requiredData } from '../lib/supabase-result';

export class MembershipsRepository {
  constructor(private readonly db: SupabaseClient) {}

  async create(input: {
    club_id: string | number;
    auth_user_id: string;
    role: TeamRole;
    status?: 'active' | 'left';
  }): Promise<MembershipRow> {
    const response = await this.db
      .from('memberships')
      .insert({
        club_id: input.club_id,
        auth_user_id: input.auth_user_id,
        role: input.role,
        status: input.status ?? 'active',
      })
      .select('*')
      .single();

    return requiredData(response) as MembershipRow;
  }

  async findById(membershipId: string | number): Promise<MembershipRow | null> {
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('id', membershipId)
      .maybeSingle();

    return optionalData(response) as MembershipRow | null;
  }

  async getById(membershipId: string | number): Promise<MembershipRow> {
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('id', membershipId)
      .maybeSingle();

    return requiredData(response, 'Membership non trovata') as MembershipRow;
  }

  async listActiveByAuthUserId(authUserId: string): Promise<MembershipRow[]> {
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('auth_user_id', authUserId)
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    return ((optionalData(response) as MembershipRow[] | null) ?? []);
  }

  async listActiveByClubId(clubId: string | number): Promise<MembershipRow[]> {
    const response = await this.db
      .from('memberships')
      .select('*')
      .eq('club_id', clubId)
      .eq('status', 'active')
      .order('created_at', { ascending: true });

    return ((optionalData(response) as MembershipRow[] | null) ?? []);
  }

  async updateRole(membershipId: string | number, role: TeamRole): Promise<void> {
    const response = await this.db
      .from('memberships')
      .update({ role })
      .eq('id', membershipId)
      .eq('status', 'active');

    if (response.error) {
      throw response.error;
    }
  }

  async markLeft(membershipId: string | number, leftAt: string): Promise<void> {
    const response = await this.db
      .from('memberships')
      .update({
        status: 'left',
        left_at: leftAt,
      })
      .eq('id', membershipId)
      .eq('status', 'active');

    if (response.error) {
      throw response.error;
    }
  }

  async deleteById(membershipId: string | number): Promise<void> {
    const response = await this.db
      .from('memberships')
      .delete()
      .eq('id', membershipId);

    if (response.error) {
      throw response.error;
    }
  }
}
