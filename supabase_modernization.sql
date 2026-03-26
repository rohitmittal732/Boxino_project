-- ==============================================================================
-- BOXINO MODERNIZATION SQL SCRIPT
-- Run this script in your Supabase SQL Editor
-- ==============================================================================

-- 1. ADD NEW PAYMENT COLUMNS TO ORDERS TABLE
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS payment_method text DEFAULT 'cash',
ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'pending';

-- 2. CREATE DATABASE INDEXES FOR PERFORMANCE
-- These speed up large queries when the app scales
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
-- NOTE: delivery_boy_id lives in the deliveries table, not orders
CREATE INDEX IF NOT EXISTS idx_deliveries_boy_id ON public.deliveries(delivery_boy_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_order_id ON public.deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON public.deliveries(status);

-- 3. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

-- 4. USERS POLICIES
-- Users can view and update their own profiles
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Only Admins can view all users or change roles (Assuming role='admin')
CREATE POLICY "Admins can view and edit all users" ON public.users 
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.users admin_check 
    WHERE admin_check.id = auth.uid() AND admin_check.role = 'admin'
  )
);

-- Note: We need a policy to allow inserting during signup
CREATE POLICY "Users can insert their own profile on signup" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);


-- 5. ORDERS POLICIES
-- Users can read and insert their own orders
CREATE POLICY "Users view own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own pending orders" ON public.orders FOR UPDATE 
USING (auth.uid() = user_id AND status = 'pending');

-- Delivery Boys can view orders they are assigned to (via deliveries table join)
CREATE POLICY "Delivery boys view assigned orders" ON public.orders 
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.deliveries d
    WHERE d.order_id = public.orders.id AND d.delivery_boy_id = auth.uid()
  )
);

-- Delivery Boys can update order status (e.g. to 'delivered')
CREATE POLICY "Delivery boys update assigned orders" ON public.orders 
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.deliveries d
    WHERE d.order_id = public.orders.id AND d.delivery_boy_id = auth.uid()
  )
);

-- Admin can manage all orders
CREATE POLICY "Admins manage all orders" ON public.orders 
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.users admin_check 
    WHERE admin_check.id = auth.uid() AND admin_check.role = 'admin'
  )
);


-- 6. DELIVERIES POLICIES
-- Delivery Boys view & update their own assigned tasks
CREATE POLICY "Delivery boys manage their deliveries" ON public.deliveries 
FOR ALL USING (auth.uid() = delivery_boy_id);

-- Admin manages all deliveries
CREATE POLICY "Admins manage all deliveries" ON public.deliveries 
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.users admin_check 
    WHERE admin_check.id = auth.uid() AND admin_check.role = 'admin'
  )
);

-- ==============================================================================
-- SUCCESS: Run complete!
-- ==============================================================================
