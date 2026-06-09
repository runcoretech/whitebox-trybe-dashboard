import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export let supabase = null;

console.log("[SUPABASE CLIENT] Initializing client... Url:", supabaseUrl, "AnonKey exists:", !!supabaseAnonKey);

if (!supabaseUrl || !supabaseAnonKey) {
  console.error("[SUPABASE CLIENT] Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY in environment variables!");
} else {
  try {
    supabase = createClient(supabaseUrl, supabaseAnonKey);
    console.log("[SUPABASE CLIENT] Supabase client initialized successfully.");
  } catch (err) {
    console.error("[SUPABASE CLIENT] Failed to initialize Supabase client:", err);
  }
}

