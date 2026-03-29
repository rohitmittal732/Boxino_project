-- 🔥 BOXINO LITE: ULTIMATE PRODUCTION STABILIZATION PATCH (V4)
-- Target: 100% Robust Sync, Zero Recursion, and Data Integrity

-- [1] CLEANUP PREVIOUS SYSTEM DEBRIS
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- [2] ROBUST SYNC TRIGGER (SYNC BETWEEN AUTH AND PUBLIC)
-- Handles both 'name' and 'display_name' from metadata for client flexibility.
-- Uses ON CONFLICT to avoid crashes during manual client-side inserts.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name, phone, role)
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'display_name', 'User'),
    COALESCE(new.raw_user_meta_data->>'phone', '0000000000'),
    COALESCE(new.raw_user_meta_data->>'role', 'user')
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(public.users.name, EXCLUDED.name),
    phone = COALESCE(public.users.phone, EXCLUDED.phone);

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach the trigger to auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- [3] SCHEMA HARDENING (DEFAULTS & CONSTRAINTS)
ALTER TABLE public.users 
  ALTER COLUMN name SET DEFAULT 'User',
  ALTER COLUMN phone SET DEFAULT '0000000000',
  ALTER COLUMN role SET DEFAULT 'user';

-- Ensure status is locked to the standards
-- pending, accepted, preparing, picked_up, out_for_delivery, delivered, cancelled
ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS orders_status_check;

ALTER TABLE orders 
  ADD CONSTRAINT orders_status_check 
  CHECK (status IN ('pending', 'accepted', 'preparing', 'picked_up', 'out_for_delivery', 'delivered', 'cancelled'));


-- [4] ZERO-RECURSION RLS POLICIES (JWT-ONLY FOR USERS)
-- We remove all 'EXISTS (SELECT FROM users)' from 'users' table to prevent RLS loops.
DROP POLICY IF EXISTS "Users/Admins can view profiles" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Allow system to insert users" ON users;

-- View: Self or Admin
CREATE POLICY "Users/Admins can view profiles"
ON users FOR SELECT
TO authenticated
USING (
  (auth.uid() = id) 
  OR 
  (auth.jwt() ->> 'role' = 'admin')
);

-- Update: Self only
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id);

-- Insert: High-integrity sync (allow trigger/client sync)
CREATE POLICY "Allow sync new users"
ON users FOR INSERT
TO authenticated
WITH CHECK (true);


-- [5] REPAIR EXISTING DATA
-- Fills nulls for existing records to prevent UI crashes.
UPDATE users SET 
  name = COALESCE(name, 'User'),
  phone = COALESCE(phone, '0000000000'),
  role = COALESCE(role, 'user')
WHERE name IS NULL OR phone IS NULL OR role IS NULL;


-- [6] LINK AUTH AND PUBLICschema
ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_id_fkey;

ALTER TABLE public.users
ADD CONSTRAINT users_id_fkey
FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


-- [7] PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ✅ PATCH V4 COMPLETE (THE ULTIMATE VERSION)
