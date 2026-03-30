-- ==========================================
-- 🛡️ Boxino: MASTER ERROR FIX (V8)
-- 🎯 Goal: Fix the 'Relationship Not Found' error for Ratings.
-- ==========================================

-- 🟢 1. RE-ESTABLISH RELATIONSHIP
-- First, identify and drop the legacy relationship to auth.users
ALTER TABLE IF EXISTS public.ratings DROP CONSTRAINT IF EXISTS ratings_user_id_fkey;

-- Now, link ratings.user_id to public.users.id (Profile table)
-- This is MANDATORY for Supabase .select('*, users(name)') to work.
ALTER TABLE public.ratings
ADD CONSTRAINT ratings_user_id_fkey
FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 🟢 2. ENSURE RLS & PERMISSIONS
-- Make sure the authenticated role can read the reviews (Social Proof)
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view ratings" ON public.ratings;
CREATE POLICY "Anyone can view ratings"
ON public.ratings FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Users can insert their own ratings" ON public.ratings;
CREATE POLICY "Users can insert their own ratings"
ON public.ratings FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 🟢 3. VERIFICATION QUERY
-- If you run this and see names, the error is 100% GONE.
-- SELECT r.*, u.name FROM public.ratings r JOIN public.users u ON u.id = r.user_id LIMIT 5;
