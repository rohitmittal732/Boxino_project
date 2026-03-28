-- ==============================================================================
-- BOXINO PRODUCTION MASTER SCHEMA
-- WARNING: Running this will redefine your RLS and triggers. 
--          Please execute this in your Supabase SQL Editor.
-- ==============================================================================

-- -------------------------------------------------------------
-- 1. AUTH JWT ROLE TRIGGER (NO RECURSION ENGINE)
-- -------------------------------------------------------------
-- This securely injects the `role` from the users table immediately into 
-- the authenticated user's JWT `app_metadata`. This enables our policies 
-- to be blazing fast and completely recursion-free.

CREATE OR REPLACE FUNCTION public.sync_role_to_jwt()
RETURNS trigger AS $$
BEGIN
  UPDATE auth.users
  SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || json_build_object('role', NEW.role)::jsonb
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to public.users table
DROP TRIGGER IF EXISTS on_user_role_change ON public.users;
CREATE TRIGGER on_user_role_change
  AFTER INSERT OR UPDATE OF role
  ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_role_to_jwt();


-- -------------------------------------------------------------
-- 2. TABLE DEFINITIONS (If not already created)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name text NOT NULL,
  phone text,
  role text DEFAULT 'user'::text,
  lat numeric,
  lng numeric,
  preference text,
  location_name text,
  fcm_token text, -- For push notifications later
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.kitchens (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  owner_id uuid REFERENCES public.users(id),
  image_url text,
  rating numeric DEFAULT 0.0,
  description text,
  is_veg boolean DEFAULT true,
  is_non_veg boolean DEFAULT false,
  lat numeric DEFAULT 0.0,
  lng numeric DEFAULT 0.0,
  address text,
  price_per_meal numeric DEFAULT 0.0,
  is_approved boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.menus (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  kitchen_id uuid REFERENCES public.kitchens(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric NOT NULL,
  description text,
  category text DEFAULT 'Veg',
  image_url text,
  is_available boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.orders (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.users(id) NOT NULL,
  kitchen_id uuid REFERENCES public.kitchens(id) NOT NULL,
  total_price numeric NOT NULL,
  status text DEFAULT 'pending', -- pending, accepted, preparing, out_for_delivery, delivered
  user_address text,
  payment_method text DEFAULT 'cash',
  payment_status text DEFAULT 'pending',
  tracking_lat numeric, 
  tracking_lng numeric,
  delivery_boy_id uuid REFERENCES public.users(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.deliveries (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  delivery_boy_id uuid REFERENCES public.users(id) NOT NULL,
  status text DEFAULT 'accepted', -- accepted, picked_up, on_the_way, delivered
  lat numeric,
  lng numeric,
  updated_at timestamptz DEFAULT now()
);


-- -------------------------------------------------------------
-- 3. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- -------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;


-- -------------------------------------------------------------
-- 4. APPLY RECURSION-FREE RLS POLICIES
-- -------------------------------------------------------------
-- IMPORTANT: We actively drop old policies here to ensure a clean slate

-- USERS TABLE -------------------------------------------------
DROP POLICY IF EXISTS "Admins can do everything on users" ON public.users;
CREATE POLICY "Admins can do everything on users" 
ON public.users FOR ALL USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

DROP POLICY IF EXISTS "Users view own profile" ON public.users;
CREATE POLICY "Users view own profile" 
ON public.users FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users update own profile" ON public.users;
CREATE POLICY "Users update own profile" 
ON public.users FOR UPDATE USING (auth.uid() = id);

-- KITCHENS TABLE ----------------------------------------------
DROP POLICY IF EXISTS "Admins manage kitchens" ON public.kitchens;
CREATE POLICY "Admins manage kitchens" 
ON public.kitchens FOR ALL USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

DROP POLICY IF EXISTS "Everyone views approved kitchens" ON public.kitchens;
CREATE POLICY "Everyone views approved kitchens" 
ON public.kitchens FOR SELECT USING (is_approved = true);

-- MENUS (ITEMS) TABLE -----------------------------------------
DROP POLICY IF EXISTS "Admins manage items" ON public.menus;
CREATE POLICY "Admins manage items" 
ON public.menus FOR ALL USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

DROP POLICY IF EXISTS "Everyone views items" ON public.menus;
CREATE POLICY "Everyone views items" 
ON public.menus FOR SELECT USING (true);

-- ORDERS TABLE ------------------------------------------------
DROP POLICY IF EXISTS "Admins manage all orders" ON public.orders;
CREATE POLICY "Admins manage all orders" 
ON public.orders FOR ALL USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

DROP POLICY IF EXISTS "Users view own orders" ON public.orders;
CREATE POLICY "Users view own orders" 
ON public.orders FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users insert own orders" ON public.orders;
CREATE POLICY "Users insert own orders" 
ON public.orders FOR INSERT WITH CHECK (user_id = auth.uid());

-- DELIVERIES TABLE --------------------------------------------
DROP POLICY IF EXISTS "Admins manage all deliveries" ON public.deliveries;
CREATE POLICY "Admins manage all deliveries" 
ON public.deliveries FOR ALL USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

DROP POLICY IF EXISTS "Delivery boy views assigned deliveries" ON public.deliveries;
CREATE POLICY "Delivery boy views assigned deliveries" 
ON public.deliveries FOR SELECT USING (delivery_boy_id = auth.uid());

DROP POLICY IF EXISTS "Delivery boy updates assigned deliveries" ON public.deliveries;
CREATE POLICY "Delivery boy updates assigned deliveries" 
ON public.deliveries FOR UPDATE USING (delivery_boy_id = auth.uid());
