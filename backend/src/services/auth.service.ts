import type { SupabaseClient } from '@supabase/supabase-js';

import type { AuthSessionDto, AuthUserDto } from '../domain/types';
import { ForbiddenError, UnauthorizedError } from '../lib/errors';

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
    emailRedirectTo?: string | null,
  ): Promise<{ verificationRequired: boolean; message: string }> {
    const response = await this.authClient.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: emailRedirectTo ?? undefined,
      },
    });

    if (response.error) {
      throw response.error;
    }

    return {
      verificationRequired: true,
      message:
        'Abbiamo inviato una mail di verifica. Conferma l indirizzo email prima di accedere a Clubline.',
    };
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
    const emailVerifiedAt =
      session.user.email_confirmed_at ?? session.user.confirmed_at ?? null;
    if (emailVerifiedAt == null) {
      await this.authClient.auth.signOut();
      throw new ForbiddenError(
        'Conferma il tuo indirizzo email prima di accedere alla piattaforma.',
      );
    }

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
