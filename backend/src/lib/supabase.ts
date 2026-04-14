import { createClient } from '@supabase/supabase-js';

import { env } from '../config/env';

const authOptions = {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
};

export const supabaseAuth = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, authOptions);
export const supabaseDb = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  authOptions,
);
