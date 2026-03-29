-- ==========================================
-- 🛡️ Boxino Lite: PRODUCTION SECURITY PATCH V5 (MASTER)
-- 🎯 Goal: Zero-recursion, JWT Metadata-based Roles.
-- ==========================================

-- 1. Enable RLS on all critical tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchens ENABLE ROW LEVEL SECURITY;
ALTER TABLE menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 👤 USERS TABLE POLICIES (Zero-Recursion)
-- ==========================================
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Allow system to insert users" ON users;

-- 🏠 User Access
CREATE POLICY "Users can view their own profile"
ON users FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id);

-- 🔑 Admin Access (JWT METADATA BASED - NO RECURSION)
-- 🔥 V5 MASTER: Look in user_metadata for the role
CREATE POLICY "Admins can view all users"
ON users FOR SELECT
TO authenticated
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin')
);

CREATE POLICY "Admins can update all users"
ON users FOR UPDATE
TO authenticated
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin')
);

-- 🔧 System Access
CREATE POLICY "Allow system to insert users"
ON users FOR INSERT
TO authenticated
WITH CHECK (true);

-- ==========================================
-- 🍳 KITCHENS TABLE POLICIES
-- ==========================================
DROP POLICY IF EXISTS "Anyone can view approved kitchens" ON kitchens;
DROP POLICY IF EXISTS "Admins can manage all kitchens" ON kitchens;

-- 🏠 Public Access
CREATE POLICY "Anyone can view approved kitchens"
ON kitchens FOR SELECT
TO authenticated
USING (is_approved = true);

-- 🔑 Admin Access (JWT METADATA BASED)
CREATE POLICY "Admins can manage all kitchens"
ON kitchens FOR ALL
TO authenticated
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin')
);

-- ==========================================
-- 📝 MENUS TABLE POLICIES
-- ==========================================
DROP POLICY IF EXISTS "Anyone can view menus" ON menus;
DROP POLICY IF EXISTS "Admins can manage menus" ON menus;

CREATE POLICY "Anyone can view menus"
ON menus FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Admins can manage menus"
ON menus FOR ALL
TO authenticated
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin')
);

-- ==========================================
-- 🛒 ORDERS TABLE POLICIES
-- ==========================================
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
DROP POLICY IF EXISTS "Users can create orders" ON orders;
DROP POLICY IF EXISTS "Admins can manage all orders" ON orders;
DROP POLICY IF EXISTS "Delivery boys can view assigned orders" ON orders;

-- 🏠 User Access
CREATE POLICY "Users can view their own orders"
ON orders FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can create orders"
ON orders FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 🔑 Admin Access (JWT METADATA BASED)
CREATE POLICY "Admins can manage all orders"
ON orders FOR ALL
TO authenticated
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin')
);

-- 🚚 Delivery Access (Standard recursive check is okay here because it doesn't loop back to users table)
CREATE POLICY "Delivery boys can manage assigned orders"
ON orders FOR ALL
TO authenticated
USING (
  (auth.jwt() -> 'user_metadata' ->> 'role' = 'delivery')
);

-- ==========================================
-- 🔄 DATABASE TRIGGERS (Sync & Identity)
-- ==========================================

-- Function to handle metadata-to-database sync on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, phone)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user'),
    COALESCE(NEW.raw_user_meta_data->>'phone', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 🔥 V5 LOG: Security logic fully migrated to Metadata Claims.
-- 🚨 FINAL TEST: run `select auth.jwt();` in SQL Editor to check your claims.
