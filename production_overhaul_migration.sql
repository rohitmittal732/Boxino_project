-- BOXINO PRODUCTION OVERHAUL MIGRATION (FINAL ALIGNMENT)

-- 1. Ensure users table has all required columns
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lat double precision;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lng double precision;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_address text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS area_name text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_online boolean DEFAULT false;

-- 2. Ensure orders table has metadata denormalization columns
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_lat double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_lng double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS area_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_phone text;

-- 3. Ensure delivery_locations/deliveries has tracking capability
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lat double precision;
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lng double precision;

-- 4. RLS POLICIES (STRICT ALIGNMENT WITH MASTER PROMPT)

-- Allow everyone to read user metadata (required for joins/profile display)
DROP POLICY IF EXISTS "Allow read users" ON public.users;
CREATE POLICY "Allow read users" ON public.users FOR SELECT USING (true);

-- Orders: Admin manage all
DROP POLICY IF EXISTS "Admins manage all orders" ON public.orders;
CREATE POLICY "Admins manage all orders" ON public.orders FOR ALL
USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- Orders: Users view own
DROP POLICY IF EXISTS "Users view own orders" ON public.orders;
CREATE POLICY "Users view own orders" ON public.orders FOR SELECT 
USING (user_id = auth.uid());

-- Orders: Delivery manage assigned
DROP POLICY IF EXISTS "Delivery manage assigned orders" ON public.orders;
CREATE POLICY "Delivery manage assigned orders" ON public.orders FOR ALL
USING (delivery_boy_id = auth.uid());

-- Deliveries: Admin manage all
DROP POLICY IF EXISTS "Admins manage all deliveries" ON public.deliveries;
CREATE POLICY "Admins manage all deliveries" ON public.deliveries FOR ALL
USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- Deliveries: Delivery manage own
DROP POLICY IF EXISTS "Delivery manage own deliveries" ON public.deliveries;
CREATE POLICY "Delivery manage own deliveries" ON public.deliveries FOR ALL
USING (delivery_boy_id = auth.uid());
