-- BOXINO PRODUCTION OVERHAUL MIGRATION

-- 1. Update public.users table with location columns
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lat double precision;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lng double precision;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_address text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS area_name text;

-- 2. Update public.orders table with user-specific location columns
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_lat double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS user_lng double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS area_name text;

-- 3. Update RLS policies for orders table to allow Admins to update status
-- First, drop the old policy if it exists to avoid conflicts
DROP POLICY IF EXISTS "Admins can update all orders" ON public.orders;
CREATE POLICY "Admins can update all orders"
ON public.orders FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- 4. Ensure Deliveries table also has lat/lng for order-specific live tracking
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lat double precision;
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lng double precision;

-- 5. Fix RLS for deliveries table to allow Admins to update/view
DROP POLICY IF EXISTS "Admins can manage all deliveries" ON public.deliveries;
CREATE POLICY "Admins can manage all deliveries"
ON public.deliveries FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);
