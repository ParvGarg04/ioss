import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = supabaseUrl && supabaseKey
  ? createClient(supabaseUrl, supabaseKey)
  : null;

/** Upload an image file to the public `images` bucket. Returns the public URL. */
export async function uploadImage(file: File): Promise<string> {
  if (!supabase) throw new Error('Supabase is not configured. Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to .env');

  const fileName = `${Date.now()}-${file.name}`;

  const { error } = await supabase.storage.from('images').upload(fileName, file);
  if (error) throw error;

  return `${import.meta.env.VITE_SUPABASE_URL}/storage/v1/object/public/images/${fileName}`;
}
