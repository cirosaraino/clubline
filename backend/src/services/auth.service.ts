import type { SupabaseClient } from '@supabase/supabase-js';

import type { AuthSessionDto, AuthUserDto } from '../domain/types';
import {
  ConflictError,
  TooManyRequestsError,
  UnauthorizedError,
} from '../lib/errors';
import { ensureSuccess, optionalData } from '../lib/supabase-result';

function toSessionDto(session: {
  access_token: string;
  refresh_token: string;
  expires_at: number | null | undefined;
  user: {
    id: string;
    email: string | null | undefined;
    email_confirmed_at?: string | null | undefined;
    confirmed_at?: string | null | undefined;
  };
}): AuthSessionDto {
  const emailVerifiedAt = session.user.email_confirmed_at ?? session.user.confirmed_at ?? null;
  return {
    accessToken: session.access_token,
    refreshToken: session.refresh_token,
    expiresAt: session.expires_at
      ? new Date(session.expires_at * 1000).toISOString()
      : new Date().toISOString(),
    user: {
      id: session.user.id,
      email: session.user.email ?? null,
      emailVerified: emailVerifiedAt != null,
      emailVerifiedAt,
    },
  };
}

export class AuthService {
  constructor(
    private readonly authClient: SupabaseClient,
    private readonly adminClient: SupabaseClient,
  ) {}

  async register(
    email: string,
    password: string,
    _emailRedirectTo?: string | null,
  ): Promise<{
    verificationRequired: boolean;
    message: string;
    session?: AuthSessionDto;
  }> {
    const createUserResponse = await this.adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createUserResponse.error) {
      throw this.mapAuthProviderError(createUserResponse.error);
    }

    const loginResponse = await this.authClient.auth.signInWithPassword({
      email,
      password,
    });
    if (loginResponse.error || !loginResponse.data.session) {
      throw loginResponse.error ??
          new UnauthorizedError('Account creato ma accesso automatico non riuscito');
    }

    return {
      verificationRequired: false,
      message: 'Account creato correttamente.',
      session: toSessionDto({
        access_token: loginResponse.data.session.access_token,
        refresh_token: loginResponse.data.session.refresh_token,
        expires_at: loginResponse.data.session.expires_at,
        user: {
          id: loginResponse.data.session.user.id,
          email: loginResponse.data.session.user.email ?? null,
          email_confirmed_at:
              loginResponse.data.session.user.email_confirmed_at ?? null,
          confirmed_at: loginResponse.data.session.user.confirmed_at ?? null,
        },
      }),
    };
  }

  private mapAuthProviderError(error: {
    message?: string | null;
    status?: number | null;
    code?: string | number | null;
  }): Error {
    const normalizedMessage = error.message?.trim().toLowerCase() ?? '';

    if (normalizedMessage.includes('email rate limit exceeded')) {
      return new TooManyRequestsError(
        'Hai raggiunto il limite temporaneo delle email di verifica. Attendi un momento e riprova, oppure controlla se hai gia ricevuto il messaggio nella tua casella email.',
      );
    }

    if (normalizedMessage.includes('already registered') ||
        normalizedMessage.includes('user already registered') ||
        normalizedMessage.includes('already been registered')) {
      return new ConflictError('Esiste gia un account registrato con questa email.');
    }

    return error as Error;
  }

  async login(email: string, password: string): Promise<{ session: AuthSessionDto }> {
    const response = await this.authClient.auth.signInWithPassword({
      email,
      password,
    });

    if (response.error || !response.data.session) {
      throw response.error ?? new UnauthorizedError('Credenziali non valide');
    }

    const session = response.data.session;
    return {
      session: toSessionDto({
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_at: session.expires_at,
        user: {
          id: session.user.id,
          email: session.user.email ?? null,
          email_confirmed_at: session.user.email_confirmed_at ?? null,
          confirmed_at: session.user.confirmed_at ?? null,
        },
      }),
    };
  }

  async refresh(refreshToken: string): Promise<{ session: AuthSessionDto }> {
    const response = await this.authClient.auth.refreshSession({
      refresh_token: refreshToken,
    });

    if (response.error || !response.data.session) {
      throw response.error ?? new UnauthorizedError('Refresh token non valido');
    }

    const session = response.data.session;
    return {
      session: toSessionDto({
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_at: session.expires_at,
        user: {
          id: session.user.id,
          email: session.user.email ?? null,
          email_confirmed_at: session.user.email_confirmed_at ?? null,
          confirmed_at: session.user.confirmed_at ?? null,
        },
      }),
    };
  }

  async logout(userId: string): Promise<{ success: true }> {
    await this.adminClient.auth.admin.signOut(userId);
    return { success: true };
  }

  async deleteAccount(userId: string): Promise<{ success: true }> {
    const activeMembershipResponse = await this.adminClient
      .from('memberships')
      .select('id')
      .eq('auth_user_id', userId)
      .eq('status', 'active')
      .limit(1)
      .maybeSingle();
    if (optionalData(activeMembershipResponse) != null) {
      throw new ConflictError(
        'Esci dal club o elimina prima il club attivo prima di cancellare l account.',
      );
    }

    const pendingJoinRequestResponse = await this.adminClient
      .from('join_requests')
      .select('id')
      .eq('requester_user_id', userId)
      .eq('status', 'pending')
      .limit(1)
      .maybeSingle();
    if (optionalData(pendingJoinRequestResponse) != null) {
      throw new ConflictError(
        'Annulla prima la richiesta di ingresso pendente prima di cancellare l account.',
      );
    }

    const archiveProfilesResponse = await this.adminClient
      .from('player_profiles')
      .update({
        auth_user_id: null,
        account_email: null,
        archived_at: new Date().toISOString(),
      })
      .eq('auth_user_id', userId)
      .is('archived_at', null);
    ensureSuccess(archiveProfilesResponse);

    const deleteResponse = await this.adminClient.auth.admin.deleteUser(userId);
    if (deleteResponse.error) {
      throw deleteResponse.error;
    }

    return { success: true };
  }

  async requestPasswordReset(
    email: string,
    redirectTo?: string | null,
  ): Promise<{ success: true; message: string }> {
    const response = await this.authClient.auth.resetPasswordForEmail(email, {
      redirectTo: redirectTo ?? undefined,
    });

    if (response.error) {
      throw response.error;
    }

    return {
      success: true,
      message:
          'Se l account esiste, abbiamo inviato una mail con le istruzioni per reimpostare la password.',
    };
  }

  async updatePassword(
    userId: string,
    password: string,
  ): Promise<{ success: true; message: string }> {
    const response = await this.adminClient.auth.admin.updateUserById(userId, {
      password,
    });

    if (response.error) {
      throw response.error;
    }

    return {
      success: true,
      message: 'Password aggiornata con successo.',
    };
  }

  async getUser(token: string): Promise<AuthUserDto> {
    const response = await this.authClient.auth.getUser(token);
    if (response.error || !response.data.user) {
      throw new UnauthorizedError('Sessione non valida');
    }

    return {
      id: response.data.user.id,
      email: response.data.user.email ?? null,
      emailVerified:
        (response.data.user.email_confirmed_at ?? response.data.user.confirmed_at) != null,
      emailVerifiedAt:
        response.data.user.email_confirmed_at ?? response.data.user.confirmed_at ?? null,
    };
  }
}
