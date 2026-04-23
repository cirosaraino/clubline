import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const booleanFromEnv = z.preprocess((value) => {
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['1', 'true', 'yes', 'on'].includes(normalized)) {
      return true;
    }

    if (['0', 'false', 'no', 'off'].includes(normalized)) {
      return false;
    }
  }

  return value;
}, z.boolean());

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3001),
  CORS_ORIGIN: z.string().default('http://localhost:3000'),
  SUPABASE_PROJECT_NAME: z.string().min(1).optional(),
  SUPABASE_PROJECT_REF: z.string().min(1).optional(),
  SUPABASE_URL: z.string().url(),
  SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  SUPABASE_DB_URL: z.string().min(1).optional(),
  ENABLE_LOCAL_REALTIME_FALLBACK: booleanFromEnv.optional(),
  ENABLE_LEGACY_WORKFLOW_FALLBACK: booleanFromEnv.optional(),
});

const parsedEnv = envSchema.parse(process.env);

const isProduction = parsedEnv.NODE_ENV === 'production';
const isTest = parsedEnv.NODE_ENV === 'test';
const enableLocalRealtimeFallback =
  parsedEnv.ENABLE_LOCAL_REALTIME_FALLBACK ?? !isProduction;
const enableLegacyWorkflowFallback =
  parsedEnv.ENABLE_LEGACY_WORKFLOW_FALLBACK ?? isTest;

if (isProduction && enableLegacyWorkflowFallback) {
  throw new Error(
    'ENABLE_LEGACY_WORKFLOW_FALLBACK non puo essere attivo in produzione. Applica le RPC hardened e disabilita il fallback legacy.',
  );
}

export const env = {
  ...parsedEnv,
  ENABLE_LOCAL_REALTIME_FALLBACK: enableLocalRealtimeFallback,
  ENABLE_LEGACY_WORKFLOW_FALLBACK: enableLegacyWorkflowFallback,
} as const;

export const corsOrigins = env.CORS_ORIGIN.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
