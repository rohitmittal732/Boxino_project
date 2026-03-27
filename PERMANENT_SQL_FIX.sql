-- ==========================================================
-- FINAL POSTGRES & SECURITY MIGRATION FIX (ULTIMATE V2)
-- (RUN THIS ENTIRE SCRIPT IN SUPABASE SQL EDITOR)
-- ==========================================================

-- 1. FIX "invalid input syntax for type integer"
ALTER TABLE public.kitchens ALTER COLUMN price_per_meal TYPE numeric USING price_per_meal::numeric;
ALTER TABLE public.menus ALTER COLUMN price TYPE numeric USING price::numeric;
ALTER TABLE public.orders ALTER COLUMN total_price TYPE numeric USING total_price::numeric;

-- 2. SCHEMA COMPLETION (COLUMNS & TABLES)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_id uuid REFERENCES public.users(id);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lat numeric;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS lng numeric;

-- 3. DELIVERIES TABLE (PRODUCTION FLOW)
CREATE TABLE IF NOT EXISTS public.deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  delivery_boy_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  status text DEFAULT 'accepted',
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(order_id) -- Prevent Double Insert Bug
);

-- 4. ROLE HELPER FUNCTION
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS text AS $$
  SELECT role FROM public.users WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- 5. RLS POLICIES (STRICT PRODUCTION MODE)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

-- [ORDERS POLICIES]
DROP POLICY IF EXISTS "Admins manage everything" ON public.orders;
DROP POLICY IF EXISTS "Delivery view" ON public.orders;
DROP POLICY IF EXISTS "Delivery update" ON public.orders;
DROP POLICY IF EXISTS "Users view own orders" ON public.orders;
DROP POLICY IF EXISTS "Users insert own orders" ON public.orders;

CREATE POLICY "Admins manage everything" ON public.orders FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Delivery view" ON public.orders FOR SELECT USING (delivery_id = auth.uid() OR get_user_role() = 'admin');
CREATE POLICY "Delivery update" ON public.orders FOR UPDATE USING (delivery_id = auth.uid() OR get_user_role() = 'admin');
CREATE POLICY "Users view own orders" ON public.orders FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own orders" ON public.orders FOR INSERT WITH CHECK (user_id = auth.uid());

-- [DELIVERIES POLICIES]
DROP POLICY IF EXISTS "Admins manage deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Delivery boy view own" ON public.deliveries;
DROP POLICY IF EXISTS "Delivery boy update own" ON public.deliveries;

CREATE POLICY "Admins manage deliveries" ON public.deliveries FOR ALL USING (get_user_role() = 'admin');
CREATE POLICY "Delivery boy view own" ON public.deliveries FOR SELECT USING (delivery_boy_id = auth.uid());
CREATE POLICY "Delivery boy update own" ON public.deliveries FOR UPDATE USING (delivery_boy_id = auth.uid());


-- 6. REPLICATION & REALTIME
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.users REPLICA IDENTITY FULL;
ALTER TABLE public.deliveries REPLICA IDENTITY FULL;

DO $$
BEGIN
  -- Add tables to realtime publication
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'orders') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'users') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'deliveries') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.deliveries;
  END IF;
END $$;
