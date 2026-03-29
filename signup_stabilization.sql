-- BOXINO SIGNUP STABILIZATION (RUN IN SUPABASE SQL EDITOR)

-- 1. DROP THE OLD TRIGGER (This is the #1 cause of "Saving new user" errors)
-- If the trigger fails, the entire Auth transaction fails.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user;

-- 2. ENSURE USERS TABLE IS CORRECT
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  name TEXT,
  phone TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'delivery', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ENABLE RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 4. POLICIES FOR MANUAL INSERT (Flutter Side)
-- Allow users to insert their own profile during signup
DROP POLICY IF EXISTS "Allow user to insert their own profile" ON public.users;
CREATE POLICY "Allow user to insert their own profile" 
ON public.users
FOR INSERT 
WITH CHECK (auth.uid() = id);

-- Allow users to see their own profile
DROP POLICY IF EXISTS "Users can see their own profile" ON public.users;
CREATE POLICY "Users can see their own profile" 
ON public.users
FOR SELECT 
USING (auth.uid() = id OR (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin');

-- Allow users to update their own profile
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile" 
ON public.users
FOR UPDATE 
USING (auth.uid() = id);

-- 5. ADMIN VIEW FOR ALL PROFILES
DROP POLICY IF EXISTS "Admin can see all profiles" ON public.users;
CREATE POLICY "Admin can see all profiles" 
ON public.users
FOR SELECT 
USING ((SELECT role FROM public.users WHERE id = auth.uid()) = 'admin');

-- 6. PUBLIC VIEW FOR RIDER LOCATIONS (Optional but recommended for tracking)
DROP POLICY IF EXISTS "Public can see basic rider info" ON public.users;
CREATE POLICY "Public can see basic rider info" 
ON public.users
FOR SELECT 
USING (role = 'delivery');
