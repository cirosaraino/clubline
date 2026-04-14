import type { RequestPrincipal } from '../domain/types';

declare global {
  namespace Express {
    interface Request {
      principal?: RequestPrincipal;
    }
  }
}

export {};
