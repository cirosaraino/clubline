import { NotFoundError } from './errors';

interface SupabaseResult<T> {
  data: T | null;
  error: Error | null;
}

export function optionalData<T>(result: SupabaseResult<T>): T | null {
  if (result.error) {
    throw result.error;
  }

  return result.data;
}

export function requiredData<T>(
  result: SupabaseResult<T>,
  notFoundMessage = 'Record non trovato',
): T {
  if (result.error) {
    throw result.error;
  }

  if (result.data == null) {
    throw new NotFoundError(notFoundMessage);
  }

  return result.data;
}

export function ensureSuccess(result: { error: Error | null }): void {
  if (result.error) {
    throw result.error;
  }
}
