import type { SupabaseClient } from '@supabase/supabase-js';

import type { AuthSessionDto, AuthUserDto } from '../domain/types';
import { UnauthorizedError } from '../lib/errors';

function toSessionDto(session: {
  access_token: string;
  refresh_token: string;
  expires_at: number | null | undefined;
  user: { id: string; email: string | null | undefined };
}): AuthSessionDto {
  return {
    accessToken: session.access_token,
    refreshToken: session.refresh_token,
    expiresAt: session.expires_at
      ? new Date(session.expires_at * 1000).toISOString()
      : new Date().toISOString(),
    user: {
      id: session.user.id,
      email: session.user.email ?? null,
    },
  };
}

export class AuthService {
  constructor(
    private readonly authClient: SupabaseClient,
    private readonly adminClient: SupabaseClient,
  ) {}

  async register(email: string, password: string): Promise<{ session: AuthSessionDto }> {
    const response = await this.adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (response.error) {
      throw response.error;
    }

    return this.login(email, password);
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
        },
      }),
    };
  }

  async logout(userId: string): Promise<{ success: true }> {
    await this.adminClient.auth.admin.signOut(userId);
    return { success: true };
  }

  async getUser(token: string): Promise<AuthUserDto> {
    const response = await this.authClient.auth.getUser(token);
    if (response.error || !response.data.user) {
      throw new UnauthorizedError('Sessione non valida');
    }

    return {
      id: response.data.user.id,
      email: response.data.user.email ?? null,
    };
  }
}
