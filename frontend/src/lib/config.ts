export const env = {
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL as string | undefined,
  supabaseKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined,
  forceDemo: String(import.meta.env.VITE_FORCE_DEMO ?? 'false').toLowerCase() === 'true'
}

export const configError = !env.forceDemo && (!env.supabaseUrl || !env.supabaseKey)
  ? 'Thiếu VITE_SUPABASE_URL hoặc VITE_SUPABASE_PUBLISHABLE_KEY trong cấu hình.'
  : null

// An unconfigured local dev server is a demo. A production build must not
// silently expose demo records when deployment configuration is incomplete.
export const isDemoMode = env.forceDemo || (import.meta.env.DEV && !!configError)
