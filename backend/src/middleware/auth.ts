import type { RequestHandler } from 'express';

import { AccessService } from '../services/access.service';
import { supabaseAuth, supabaseDb } from '../lib/supabase';
import { UnauthorizedError } from '../lib/errors';
import type { AuthUserDto } from '../domain/types';

function extractBearerToken(authorizationHeader: string | undefined): string | null {
  if (!authorizationHeader) {
    return null;
  }

  const [scheme, token] = authorizationHeader.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) {
    return null;
  }

  return token.trim();
}

export const requireAuth: RequestHandler = async (req, _res, next) => {
  try {
    const token = extractBearerToken(req.headers.authorization);
    if (!token) {
      throw new UnauthorizedError('Token mancante');
    }

    const authService = new AccessService(supabaseDb);
    const response = await supabaseAuth.auth.getUser(token);
    if (response.error || !response.data.user) {
      throw new UnauthorizedError('Sessione non valida');
    }

    const authUser: AuthUserDto = {
      id: response.data.user.id,
      email: response.data.user.email ?? null,
    };

    const principal = await authService.resolvePrincipal(authUser);
    req.principal = principal;
    next();
  } catch (error) {
    next(error);
  }
};
