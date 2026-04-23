import { z } from 'zod';

export const listClubsQuerySchema = z.object({
  q: z.string().trim().max(80).optional(),
  page: z.coerce.number().int().min(1).max(500).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const createClubSchema = z.object({
  name: z.string().min(1),
  logo_data_url: z.string().min(1).nullable().optional(),
  owner_nome: z.string().min(1),
  owner_cognome: z.string().min(1),
  owner_id_console: z.string().min(1),
  owner_shirt_number: z.number().int().nullable().optional(),
  owner_primary_role: z.string().min(1).nullable().optional(),
  primary_color: z.string().min(1).nullable().optional(),
  accent_color: z.string().min(1).nullable().optional(),
  surface_color: z.string().min(1).nullable().optional(),
});

export const joinClubSchema = z.object({
  club_id: z.union([z.string().min(1), z.number()]),
  requested_nome: z.string().min(1).nullable().optional(),
  requested_cognome: z.string().min(1).nullable().optional(),
  requested_shirt_number: z.number().int().nullable().optional(),
  requested_primary_role: z.string().min(1).nullable().optional(),
});

export const updateLogoSchema = z.object({
  logo_data_url: z.string().min(1),
  primary_color: z.string().min(1).nullable().optional(),
  accent_color: z.string().min(1).nullable().optional(),
  surface_color: z.string().min(1).nullable().optional(),
});

export const transferCaptainSchema = z.object({
  target_membership_id: z.union([z.string().min(1), z.number()]),
});
