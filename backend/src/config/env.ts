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

const appEnvironmentSchema = z.enum(['local', 'dev', 'prod']);
const nodeEnvironmentSchema = z.enum(['development', 'test', 'production']);

const defaultLocalCorsOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:8080',
  'http://127.0.0.1:8080',
  'http://localhost:4100',
  'http://127.0.0.1:4100',
  'http://localhost:4101',
  'http://127.0.0.1:4101',
  'http://localhost:4102',
  'http://127.0.0.1:4102',
].join(',');

const envSchema = z.object({
  APP_ENV: appEnvironmentSchema.optional(),
  NODE_ENV: nodeEnvironmentSchema.default('development'),
  PORT: z.coerce.number().int().positive().default(3001),
  CORS_ALLOWED_ORIGINS: z.string().optional(),
  CORS_ORIGIN: z.string().optional(),
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

function deriveAppEnvironment(
  rawAppEnvironment: z.infer<typeof appEnvironmentSchema> | undefined,
  nodeEnvironment: z.infer<typeof nodeEnvironmentSchema>,
): z.infer<typeof appEnvironmentSchema> {
  if (rawAppEnvironment) {
    return rawAppEnvironment;
  }

  if (nodeEnvironment === 'production') {
    return 'prod';
  }

  return 'local';
}

function parseCorsOrigins(rawValue: string): string[] {
  return rawValue
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function isLocalHostUrl(rawValue: string): boolean {
  try {
    const url = new URL(rawValue);
    const host = url.hostname.trim().toLowerCase();
    return host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0';
  } catch {
    return false;
  }
}

const appEnvironment = deriveAppEnvironment(parsedEnv.APP_ENV, parsedEnv.NODE_ENV);
const isProduction = appEnvironment === 'prod';
const isLocal = appEnvironment === 'local';
const isDevelopment = appEnvironment === 'dev';
const isTest = parsedEnv.NODE_ENV === 'test';
const corsOrigins = parseCorsOrigins(
  parsedEnv.CORS_ALLOWED_ORIGINS ?? parsedEnv.CORS_ORIGIN ?? defaultLocalCorsOrigins,
);
const enableLocalRealtimeFallback =
  parsedEnv.ENABLE_LOCAL_REALTIME_FALLBACK ?? isLocal;
const enableLegacyWorkflowFallback =
  parsedEnv.ENABLE_LEGACY_WORKFLOW_FALLBACK ?? isTest;

if (isProduction && enableLegacyWorkflowFallback) {
  throw new Error(
    'ENABLE_LEGACY_WORKFLOW_FALLBACK non puo essere attivo in produzione. Applica le RPC hardened e disabilita il fallback legacy.',
  );
}

if (isProduction && enableLocalRealtimeFallback) {
  throw new Error(
    'ENABLE_LOCAL_REALTIME_FALLBACK non puo essere attivo in produzione. Usa Supabase Realtime come percorso primario.',
  );
}

if (isProduction && parsedEnv.NODE_ENV != 'production') {
  throw new Error(
    `APP_ENV=prod richiede NODE_ENV=production. Valore ricevuto: ${parsedEnv.NODE_ENV}.`,
  );
}

if (!isProduction && parsedEnv.NODE_ENV == 'production') {
  throw new Error(
    `NODE_ENV=production e consentito solo con APP_ENV=prod. Valore ricevuto: APP_ENV=${appEnvironment}.`,
  );
}

if (isProduction && corsOrigins.some((origin) => isLocalHostUrl(origin))) {
  throw new Error(
    'APP_ENV=prod non puo includere origini locali in CORS_ALLOWED_ORIGINS.',
  );
}

if (isProduction && isLocalHostUrl(parsedEnv.SUPABASE_URL)) {
  throw new Error(
    'APP_ENV=prod non puo usare un SUPABASE_URL locale.',
  );
}

export const env = {
  ...parsedEnv,
  APP_ENV: appEnvironment,
  CORS_ALLOWED_ORIGINS: corsOrigins.join(','),
  ENABLE_LOCAL_REALTIME_FALLBACK: enableLocalRealtimeFallback,
  ENABLE_LEGACY_WORKFLOW_FALLBACK: enableLegacyWorkflowFallback,
} as const;

export const appEnv = env.APP_ENV;
export const isLocalAppEnvironment = isLocal;
export const isDevelopmentAppEnvironment = isDevelopment;
export const isProductionAppEnvironment = isProduction;
export { corsOrigins };
