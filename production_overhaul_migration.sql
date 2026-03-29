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
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS admin_eta integer DEFAULT 30;

-- 3. STATUS CONSTRAINT FIX (FOR CANCEL WORK)
DO $$ 
BEGIN 
    ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
    ALTER TABLE public.orders ADD CONSTRAINT orders_status_check 
    CHECK (status IN ('pending', 'accepted', 'preparing', 'picked_up', 'out_for_delivery', 'delivered', 'cancelled'));
EXCEPTION WHEN OTHERS THEN 
    -- If constraint doesn't exist, just move on
END $$;

-- 4. SIGNUP TRIGGER FIX (MANDATORY)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, name, phone, role)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'display_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    'user'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Ensure delivery_locations/deliveries has tracking capability
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lat double precision;
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS lng double precision;

-- 6. RLS POLICIES (STRICT ALIGNMENT)
DROP POLICY IF EXISTS "Allow read users" ON public.users;
CREATE POLICY "Allow read users" ON public.users FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins manage all orders" ON public.orders;
CREATE POLICY "Admins manage all orders" ON public.orders FOR ALL
USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

DROP POLICY IF EXISTS "Users view own orders" ON public.orders;
CREATE POLICY "Users view own orders" ON public.orders FOR SELECT 
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Delivery manage assigned orders" ON public.orders;
CREATE POLICY "Delivery manage assigned orders" ON public.orders FOR ALL
USING (delivery_boy_id = auth.uid());

-- 7. Deliveries RLS (Admin & Delivery Boy)
DROP POLICY IF EXISTS "Admins manage all deliveries" ON public.deliveries;
CREATE POLICY "Admins manage all deliveries" ON public.deliveries FOR ALL
USING ((auth.jwt()->'app_metadata'->>'role') = 'admin');

DROP POLICY IF EXISTS "Delivery manage own deliveries" ON public.deliveries;
CREATE POLICY "Delivery manage own deliveries" ON public.deliveries FOR ALL
USING (delivery_boy_id = auth.uid());

