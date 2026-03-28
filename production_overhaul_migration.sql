-- BOXINO PRODUCTION OVERHAUL MIGRATION (FINAL VISIBILITY FIX)

-- 1. Update public.users table with location columns
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lat double precision;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lng double precision;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_address text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS area_name text;

-- 2. Update public.orders table with user-specific location columns
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_lat double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_lng double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS area_name text;

-- 3. Update RLS policies for orders table
-- Drops to avoid conflicts
DROP POLICY IF EXISTS "Admins can update all orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Riders can view assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;

-- Admin: FULL access for visibility and status updates
CREATE POLICY "Admins can manage all orders" ON public.orders FOR ALL
USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

-- Delivery Boy (Rider): View their assigned orders
CREATE POLICY "Riders can view assigned orders" ON public.orders FOR SELECT
USING (delivery_boy_id = auth.uid());

-- Delivery Boy (Rider): Update status and tracking on their assigned orders
CREATE POLICY "Riders can update assigned orders" ON public.orders FOR UPDATE
USING (delivery_boy_id = auth.uid());

-- Users: View their own orders
CREATE POLICY "Users can view own orders" ON public.orders FOR SELECT
USING (user_id = auth.uid());

-- 4. Deliveries table hardening
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lat double precision;
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lng double precision;

DROP POLICY IF EXISTS "Admins can manage all deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Riders can view assigned deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Riders can update assigned deliveries" ON public.deliveries;

-- Admin: FULL access
CREATE POLICY "Admins can manage all deliveries" ON public.deliveries FOR ALL
USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

-- Rider: Manage their own deliveries
CREATE POLICY "Riders can manage own deliveries" ON public.deliveries FOR ALL
USING (delivery_boy_id = auth.uid());
