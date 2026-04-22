import type { TeamRole } from './types';

export interface NormalizedPlayerIdentityInput {
  nome: string;
  cognome: string;
  accountEmail: string | null;
  shirtNumber: number | null;
  primaryRole: string | null;
  secondaryRoles: string[];
  idConsole: string | null;
  teamRole: TeamRole;
}

export function normalizeText(value: string | null | undefined): string {
  return value?.trim() ?? '';
}

export function normalizeOptionalText(
  value: string | null | undefined,
): string | null {
  const normalized = normalizeText(value);
  return normalized.length > 0 ? normalized : null;
}

export function normalizeOptionalTextField(
  value: string | null | undefined,
): string | null | undefined {
  if (value === undefined) {
    return undefined;
  }

  return normalizeOptionalText(value);
}

export function normalizeEmail(value: string | null | undefined): string | null {
  const normalized = normalizeText(value).toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

export function normalizeEmailField(
  value: string | null | undefined,
): string | null | undefined {
  if (value === undefined) {
    return undefined;
  }

  return normalizeEmail(value);
}

export function normalizeRoles(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter(Boolean);
}

export function normalizeTeamRole(
  value: unknown,
  fallback: TeamRole = 'player',
): TeamRole {
  return value === 'captain' || value === 'vice_captain' || value === 'player'
    ? value
    : fallback;
}

export function inferNamesFromEmail(
  email: string | null | undefined,
): { nome: string; cognome: string } {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) {
    return { nome: 'Nuovo', cognome: 'Membro' };
  }

  const localPart = normalizedEmail.split('@')[0] ?? '';
  const cleaned = localPart.replaceAll(/[^a-zA-Z0-9]+/g, ' ').trim();
  const segments = cleaned
    .split(/\s+/)
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0);

  if (segments.length === 0) {
    return { nome: 'Nuovo', cognome: 'Membro' };
  }

  return {
    nome: capitalize(segments[0] ?? ''),
    cognome:
      segments.length > 1 ? capitalize(segments.slice(1).join(' ')) : 'Membro',
  };
}

export function normalizePlayerIdentityInput(input: {
  nome?: string | null;
  cognome?: string | null;
  account_email?: string | null;
  shirt_number?: number | null;
  primary_role?: string | null;
  secondary_role?: string | null;
  secondary_roles?: string[] | null;
  id_console?: string | null;
  team_role?: TeamRole | null;
}): NormalizedPlayerIdentityInput {
  const primaryRole = normalizeOptionalText(input.primary_role);
  const secondaryRoles = normalizeRoles([
    ...(input.secondary_roles ?? []),
    ...(input.secondary_role ? [input.secondary_role] : []),
  ]).filter((role) => role !== primaryRole);

  return {
    nome: normalizeText(input.nome),
    cognome: normalizeText(input.cognome),
    accountEmail: normalizeEmail(input.account_email),
    shirtNumber: input.shirt_number ?? null,
    primaryRole,
    secondaryRoles,
    idConsole: normalizeOptionalText(input.id_console),
    teamRole: normalizeTeamRole(input.team_role),
  };
}

function capitalize(value: string): string {
  if (value.length === 0) {
    return value;
  }

  return `${value[0]?.toUpperCase() ?? ''}${value.substring(1).toLowerCase()}`;
}
