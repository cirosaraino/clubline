import { ConflictError, ForbiddenError, HttpError, ValidationError } from './errors';

type MaybeSupabaseError = {
  code?: string;
  message?: string;
  details?: unknown;
};

export function mapDatabaseError(error: unknown): Error {
  if (error instanceof HttpError) {
    return error;
  }

  const supabaseError = error as MaybeSupabaseError;
  const message = supabaseError.message?.toLowerCase() ?? '';

  if (supabaseError.code === '23505' || message.includes('duplicate key')) {
    return new ConflictError('Record gia presente');
  }

  if (supabaseError.code === '23503') {
    return new ConflictError('Record collegato ad altre entita');
  }

  if (supabaseError.code === '42501' || message.includes('row-level security')) {
    return new ForbiddenError('Operazione non consentita dai permessi correnti');
  }

  if (supabaseError.code === '22P02' || message.includes('invalid input syntax')) {
    return new ValidationError('Parametri non validi');
  }

  return error instanceof Error ? error : new Error('Errore imprevisto');
}
