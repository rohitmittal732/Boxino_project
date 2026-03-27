-- Execute this exact script in your Supabase SQL Editor
-- This fixes the assignment error where the "delivery_id" column was missing.

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_id uuid REFERENCES public.users(id);

-- Optional: Since we added this column, it's good practice to ensure Realtime works on it.
-- But the table is already set to Realtime in the main script, so this single line above is 100% all you need!
