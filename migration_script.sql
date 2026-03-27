-- =========================================================
-- RUN THIS ENTIRE SCRIPT IN YOUR SUPABASE SQL EDITOR NOW!
-- =========================================================

-- 1. ADD THE MISSING COLUMN (Fixes the Postgres "column does not exist" Exception)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_id uuid REFERENCES public.users(id);

-- 2. RESTORE OLD ASSIGNMENTS (Fixes "admin toh assign kar diya woh kaha kara")
UPDATE public.orders
SET delivery_id = d.delivery_boy_id,
    status = d.status
FROM public.deliveries d
WHERE public.orders.id = d.order_id
  AND public.orders.delivery_id IS NULL;

-- 3. UNBLOCK DELIVERY BOYS (Fixes "no new orders are available" and Earnings block)
-- Drop old or conflicting policies first
DROP POLICY IF EXISTS "Delivery Boy views pending or assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Delivery Boy updates assigned orders" ON public.orders;

-- Let Delivery Boys view Orders that are 'pending' (so they show up in New Orders Tab)
-- or Orders that are actively assigned to them (so they show up in Tasks & Earnings).
CREATE POLICY "Delivery Boy views pending or assigned orders"
ON public.orders FOR SELECT 
USING (
  (((auth.jwt()->'app_metadata'->>'role') = 'delivery') AND (status = 'pending'))
  OR 
  (delivery_id = auth.uid())
);

-- Let Delivery Boys accept pending orders, update their status, or finish them.
CREATE POLICY "Delivery Boy updates assigned orders"
ON public.orders FOR UPDATE 
USING (
  (((auth.jwt()->'app_metadata'->>'role') = 'delivery') AND (status = 'pending'))
  OR 
  (delivery_id = auth.uid())
);
