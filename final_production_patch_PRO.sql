-- 🔥 BOXINO LITE: FINAL PRODUCTION STABILIZATION PATCH
-- Target: Resolve Trigger Dependencies, RLS Recursion, and Schema Cleanup

-- 🚨 1. FIX TRIGGER DEPENDENCY ISSUE
-- We must remove the trigger and function before dropping the column
DROP TRIGGER IF EXISTS on_order_assign_delivery ON orders;
DROP FUNCTION IF EXISTS handle_order_assign_delivery(); -- Standard naming
DROP FUNCTION IF EXISTS on_order_assign_delivery();   -- Legacy naming check

-- Now safely drop the legacy column if it still exists
ALTER TABLE orders DROP COLUMN IF EXISTS delivery_id;


-- 🚨 2. FIX RLS INFINITE RECURSION
-- Recursion happens when a policy on 'users' queries the 'users' table using EXISTS
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Enable read access for all active users" ON users;

-- Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Best Practice: Use JWT metadata for role checks to avoid table recursion
CREATE POLICY "Admins can view all users"
ON users FOR SELECT
TO authenticated
USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY "Users can view their own profile"
ON users FOR ALL
TO authenticated
USING (auth.uid() = id);


-- 🚨 3. CLEAN & HARDEN USERS TABLE (PUBLIC SCHEMA)
-- We ensure a clean link to auth.users without bloating the public table
-- Note: We use ALTER instead of DROP to preserve existing critical production data if any, 
-- but since the user requested a "Clean" table, we follow the structure strictly.

-- First, ensure columns match the 'Lite' requirements
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS user_address text,
  ADD COLUMN IF NOT EXISTS area_name text,
  ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false;

-- Remove location columns (Map Removal)
ALTER TABLE public.users 
  DROP COLUMN IF EXISTS lat,
  DROP COLUMN IF EXISTS lng;


-- 🚨 4. CLEAN DELIVERIES SCHEMA
ALTER TABLE deliveries 
  DROP COLUMN IF EXISTS lat,
  DROP COLUMN IF EXISTS lng;

-- Ensure deliveries table has essential fields for status tracking
ALTER TABLE deliveries
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'accepted',
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();


-- 🚨 5. DATA INTEGRITY: ADD CONSTRAINTS
-- Ensure role is strictly checked
ALTER TABLE users 
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users
ADD CONSTRAINT users_role_check
CHECK (role IN ('user', 'admin', 'delivery'));

-- Ensure order status is strictly checked
ALTER TABLE orders
DROP CONSTRAINT IF EXISTS orders_status_check;

ALTER TABLE orders
ADD CONSTRAINT orders_status_check
CHECK (status IN ('pending', 'accepted', 'preparing', 'picked_up', 'out_for_delivery', 'delivered', 'cancelled'));


-- 🚨 6. RE-SYNC AUTH TRIGGER (FINAL VERSION)
-- Ensures public.users is ALWAYS in sync with auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'name', 'User'),
    COALESCE(new.raw_user_meta_data->>'role', 'user')
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(EXCLUDED.name, public.users.name);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ✅ PATCH COMPLETE
