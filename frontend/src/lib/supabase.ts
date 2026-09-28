import { createClient } from '@supabase/supabase-js'
import { configError, env, isDemoMode } from './config'

export const supabase = isDemoMode || configError
  ? null
  : createClient(env.supabaseUrl!, env.supabaseKey!, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    })
