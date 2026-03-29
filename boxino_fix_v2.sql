-- BOXINO PRODUCTION FIX V2 (RUN THIS AFTER PREVIOUS MIGRATIONS)

-- 1. ADD ADMIN ETA COLUMN

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS admin_eta integer DEFAULT 30;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lat double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_lng double precision;
ALTER TABLE public.orders ALTER COLUMN status SET DEFAULT 'pending';



-- 2. STATUS CONSTRAINT FIX (FOR CANCEL WORK & PREPARING STATE)
-- This drops the old constraint if it exists and adds the new one including 'cancelled' and 'preparing'
DO $$ 
BEGIN 
    ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
    ALTER TABLE public.orders ADD CONSTRAINT orders_status_check 
    CHECK (status IN ('pending', 'accepted', 'preparing', 'picked_up', 'out_for_delivery', 'delivered', 'cancelled'));
EXCEPTION WHEN OTHERS THEN 
    NULL; 
END $$;

-- 3. SIGNUP TRIGGER FIX (ENSURES PROFILE SYNC)
-- This ensures name and phone are correctly captured from Auth metadata during signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, name, phone, role)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    'user'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RE-ATTACH TRIGGER
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. INDEXING FOR SCALABILITY (10K USERS READY)
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_boy_id ON public.orders(delivery_boy_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_deliveries_order_id ON public.deliveries(order_id);

-- 6. RLS FOR CANCELLATION (CANCEL ONLY PENDING)
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "cancel only pending" ON public.orders;
    CREATE POLICY "cancel only pending" ON public.orders
    FOR UPDATE 
    USING (auth.uid() = user_id AND status = 'pending');
EXCEPTION WHEN OTHERS THEN 
    NULL;
END $$;


