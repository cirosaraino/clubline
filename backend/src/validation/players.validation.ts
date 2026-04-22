import { z } from 'zod';

export const playerInputSchema = z.object({
  nome: z.string().min(1),
  cognome: z.string().min(1),
  account_email: z.string().email().nullable().optional(),
  shirt_number: z.number().int().nullable().optional(),
  primary_role: z.string().nullable().optional(),
  secondary_role: z.string().nullable().optional(),
  secondary_roles: z.array(z.string()).nullable().optional(),
  id_console: z.string().min(1).nullable().optional(),
  team_role: z.enum(['captain', 'vice_captain', 'player']).nullable().optional(),
});
