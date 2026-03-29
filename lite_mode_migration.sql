-- ========================================================
-- BOXINO LITE MODE - PRODUCTION CONSOLIDATION
-- ========================================================

-- 1. CLEAN UP MAP/GPS COLUMNS (REMOVE LOAD)
ALTER TABLE orders DROP COLUMN IF EXISTS user_lat;
ALTER TABLE orders DROP COLUMN IF EXISTS user_lng;
ALTER TABLE orders DROP COLUMN IF EXISTS delivery_lat;
ALTER TABLE orders DROP COLUMN IF EXISTS delivery_lng;

ALTER TABLE kitchens DROP COLUMN IF EXISTS lat;
ALTER TABLE kitchens DROP COLUMN IF EXISTS lng;

ALTER TABLE users DROP COLUMN IF EXISTS lat;
ALTER TABLE users DROP COLUMN IF EXISTS lng;

DROP TABLE IF EXISTS delivery_locations;

-- 2. ETA SYSTEM (DEFAULT 30 MIN)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS admin_eta integer DEFAULT 30;

-- 3. FIX KITCHEN DELETION (FOREIGN KEY CONFLICT)
-- Note: 'orders_kitchen_id_fkey' is the standard name or you can check your schema
-- This allows deleting a kitchen while keeping order history (NULL instead of delete)
ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS orders_kitchen_id_fkey;

ALTER TABLE orders
  ADD CONSTRAINT orders_kitchen_id_fkey
  FOREIGN KEY (kitchen_id)
  REFERENCES kitchens(id)
  ON DELETE SET NULL;

-- 4. CONSOLIDATE USERS TABLE & AUTH SYNC
-- Drop the problematic table and recreate it clean
-- Note: CASCADE will handle any dependent views/policies
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
  id uuid PRIMARY KEY,
  name text,
  email text,
  phone text,
  role text DEFAULT 'user',
  user_address text,
  area_name text,
  is_online boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- ROBUST AUTH SYNC TRIGGER
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, name, email, phone, role)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'name', 'New User'),
    new.email, -- email is required in Auth
    COALESCE(new.raw_user_meta_data->>'phone', ''),
    COALESCE(new.raw_user_meta_data->>'role', 'user')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- RLS FOR USERS TABLE (ADMIN CAN SEE ALL, USERS CAN SEE THEMSELVES)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all users"
  ON users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 5. DEFAULT KITCHEN IMAGE UPDATE
UPDATE kitchens
SET image_url = 'https://www.eurokidsindia.com/blog/wp-content/uploads/2023/03/best-healthy-food-for-kids-1.png'
WHERE image_url IS NULL OR image_url = '';

-- FINAL STATUS REFINEMENT (SIMPLIFIED)
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'pending',
    'accepted',
    'preparing',
    'picked',
    'on_the_way',
    'delivered',
    'cancelled'
  ));
