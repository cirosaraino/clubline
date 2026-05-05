import { ConflictError, ForbiddenError, HttpError, ValidationError } from './errors';
import { NotFoundError } from './errors';

type MaybeSupabaseError = {
  code?: string;
  message?: string;
  details?: unknown;
};

function detailCode(error: MaybeSupabaseError): string | null {
  return typeof error.details === 'string' && error.details.trim().length > 0
    ? error.details.trim()
    : null;
}

export function mapDatabaseError(error: unknown): Error {
  if (error instanceof HttpError) {
    return error;
  }

  const supabaseError = error as MaybeSupabaseError;
  const message = supabaseError.message?.toLowerCase() ?? '';
  const code = detailCode(supabaseError);

  switch (code) {
    case 'pending_club_invite_exists':
    case 'target_user_has_active_membership':
    case 'pending_join_request_same_club':
    case 'pending_join_request_other_club':
    case 'invite_not_pending':
    case 'active_membership_exists':
      return new ConflictError(supabaseError.message ?? 'Operazione in conflitto', code);
    case 'invite_management_forbidden':
      return new ForbiddenError(
        supabaseError.message ?? 'Operazione non consentita dai permessi correnti',
        code,
      );
    case 'invite_not_found':
      return new NotFoundError(supabaseError.message ?? 'Invito non trovato', code);
    case 'invite_not_owned':
      return new NotFoundError('Invito non trovato', 'invite_not_found');
    case 'target_user_not_found':
      return new NotFoundError(
        supabaseError.message ?? 'Utente di destinazione non trovato',
        code,
      );
    case 'invalid_invite_users':
    case 'self_invite_forbidden':
    case 'invalid_notification_recipient':
    case 'notification_title_required':
    case 'notification_type_required':
    case 'invalid_notification_metadata':
    case 'invalid_target_user':
      return new ValidationError(supabaseError.message ?? 'Parametri non validi', undefined, code);
    default:
      break;
  }

  if (supabaseError.code === '23505' || message.includes('duplicate key')) {
    return new ConflictError('Record gia presente');
  }

  if (
    supabaseError.code === 'P0001' ||
    supabaseError.code === '23514' ||
    message.includes('gia stata gestita') ||
    message.includes('appartieni gia') ||
    message.includes('esiste gia')
  ) {
    return new ConflictError(supabaseError.message ?? 'Operazione in conflitto');
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

  if (supabaseError.code === '22023') {
    return new ValidationError(supabaseError.message ?? 'Parametri non validi');
  }

  return error instanceof Error ? error : new Error('Errore imprevisto');
}
