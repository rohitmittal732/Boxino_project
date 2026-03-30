-- ==========================================
-- 🛡️ Boxino: RATINGS RELATIONSHIP FIX (V2)
-- 🎯 Goal: Fix the foreign key reference for ratings.
-- ==========================================

-- 1. Drop existing fkey to auth.users (if any)
ALTER TABLE IF EXISTS public.ratings DROP CONSTRAINT IF EXISTS ratings_user_id_fkey;

-- 2. Add correct fkey to public.users (Profile table)
-- This ensures Supabase 'select(*, users(*))' works correctly.
ALTER TABLE public.ratings
ADD CONSTRAINT ratings_user_id_fkey
FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 3. Verification Query (Run manually to test)
-- SELECT r.*, u.name FROM ratings r JOIN users u ON u.id = r.user_id;
