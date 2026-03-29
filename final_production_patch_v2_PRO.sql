-- 🔥 BOXINO LITE: FINAL PRODUCTION SECURITY & STRUCTURAL PATCH (V2)
-- Target: Harden RLS, Secure Admin Access, and Link Auth to Public Schema

-- 🚨 1. HARDEN USER RLS (STRICT SELECT/UPDATE)
-- We separate SELECT and UPDATE to prevent users from deleting their own records
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;

-- SELECT: Allow users to read their own data
CREATE POLICY "Users can view their own profile"
ON users FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- UPDATE: Allow users to update their own data (but not delete)
CREATE POLICY "Users can update their own profile"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id);


-- 🚨 2. SECURE ADMIN ACCESS (JWT + DB FALLBACK)
-- Uses JWT for speed, but falls back to DB check for reliability if role metadata is missing
DROP POLICY IF EXISTS "Admins can view all users" ON users;

CREATE POLICY "Admins can view all users"
ON users FOR SELECT
TO authenticated
USING (
  (auth.jwt() ->> 'role' = 'admin')
  OR 
  (EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  ))
);


-- 🚨 3. LINK PUBLIC USERS TO AUTH SCHEMA (TOTAL INTEGRITY)
-- Ensures that no public user can exist without a corresponding auth user
ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_id_fkey;

ALTER TABLE public.users
ADD CONSTRAINT users_id_fkey
FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


-- 🚨 4. PERFORMANCE INDEXING
-- Crucial for fast role-based lookups and Admin dashboard performance
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);


-- 🚨 5. DATA CLEANUP (LITE MODE FINAL)
-- Dropping any remaining location debris from orders to keep it 100% Lite
ALTER TABLE orders 
  DROP COLUMN IF EXISTS pickup_lat,
  DROP COLUMN IF EXISTS pickup_lng,
  DROP COLUMN IF EXISTS destination_lat,
  DROP COLUMN IF EXISTS destination_lng;

-- ✅ PATCH V2 COMPLETE
