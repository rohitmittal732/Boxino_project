-- BOXINO SWIGGY-FLOW MIGRATION
-- Use these SQL commands in your Supabase SQL Editor.

-- 1. Ensure public.users has 'phone' column and set it to NOT NULL
-- (Adding column if not exists, then updating existing rows to avoid NOT NULL violations)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone text;

UPDATE public.users SET phone = '9999999999' WHERE phone IS NULL;

ALTER TABLE public.users ALTER COLUMN phone SET NOT NULL;

-- 2. CREATE NEW USER TRIGGER
-- This ensures that when a user signs up, they get a profile in public.users automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, name, phone, role)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'display_name', 'User'),
    coalesce(new.raw_user_meta_data->>'phone', '9999999999'),
    'user'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. BACKFILL EXISTING USERS
-- For any user already in auth.users but missing in public.users
INSERT INTO public.users (id, name, phone, role)
SELECT 
    id, 
    coalesce(raw_user_meta_data->>'display_name', 'User'),
    coalesce(raw_user_meta_data->>'phone', '9999999999'),
    'user'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 4. Update orders table: ADD column delivery_boy_id
-- (Allowing it to be nullable initially to avoid issues with existing orders)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_boy_id uuid REFERENCES public.users(id);

-- 3. Sync delivery_boy_id with existing delivery_id if it exists
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='delivery_id') THEN
        UPDATE public.orders SET delivery_boy_id = delivery_id WHERE delivery_boy_id IS NULL;
    END IF;
END $$;

-- 4. Correct RLS Policies for deliveries table
-- 4.1. Allow Delivery Boys to INSERT their assigned deliveries
CREATE POLICY "Delivery boy inserts own record"
ON public.deliveries FOR INSERT
WITH CHECK (delivery_boy_id = auth.uid());

-- 4.2. Allow Delivery Boys to UPDATE their own assigned deliveries
CREATE POLICY "Delivery boy updates own record"
ON public.deliveries FOR UPDATE
USING (delivery_boy_id = auth.uid());

-- 4.3. Allow Delivery Boys to UPDATE order status
CREATE POLICY "Delivery boy updates assigned orders"
ON public.orders FOR UPDATE
USING (delivery_boy_id = auth.uid());

-- 4.4. Allow Users to view their own order's delivery progress
CREATE POLICY "User views assigned delivery"
ON public.deliveries FOR SELECT
USING (order_id IN (SELECT id FROM public.orders WHERE user_id = auth.uid()));

-- 5. Fix column names consistency (ensure lat/lng is used)
-- (Renames if needed, though they already exist for deliveries)
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='deliveries' AND column_name='latitude') THEN
        ALTER TABLE public.deliveries RENAME COLUMN latitude TO lat;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='deliveries' AND column_name='longitude') THEN
        ALTER TABLE public.deliveries RENAME COLUMN longitude TO lng;
    END IF;
END $$;
