import type { RequestHandler } from 'express';

import { AccessService } from '../services/access.service';
import { supabaseAuth, supabaseDb } from '../lib/supabase';
import { UnauthorizedError } from '../lib/errors';
import type { AuthUserDto } from '../domain/types';

const accessService = new AccessService(supabaseDb);

export function extractBearerToken(
  authorizationHeader: string | undefined,
): string | null {
  if (!authorizationHeader) {
    return null;
  }

  const [scheme, token] = authorizationHeader.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) {
    return null;
  }

  return token.trim();
}

export async function resolvePrincipalFromToken(token: string) {
  const response = await supabaseAuth.auth.getUser(token);
  if (response.error || !response.data.user) {
    throw new UnauthorizedError('Sessione non valida');
  }

  const authUser: AuthUserDto = {
    id: response.data.user.id,
    email: response.data.user.email ?? null,
    emailVerified:
      (response.data.user.email_confirmed_at ?? response.data.user.confirmed_at) != null,
    emailVerifiedAt:
      response.data.user.email_confirmed_at ?? response.data.user.confirmed_at ?? null,
  };

  return accessService.resolvePrincipal(authUser);
}

export const requireAuth: RequestHandler = async (req, _res, next) => {
  try {
    const token = extractBearerToken(req.headers.authorization);
    if (!token) {
      throw new UnauthorizedError('Token mancante');
    }

    const principal = await resolvePrincipalFromToken(token);
    req.principal = principal;
    next();
  } catch (error) {
    next(error);
  }
};
