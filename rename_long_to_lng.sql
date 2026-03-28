-- SQL to rename 'long' columns to 'lng' for consistency across the application
-- Run this in your Supabase SQL Editor

-- 1. Rename 'long' to 'lng' in 'users' table if it exists
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='long') THEN
        ALTER TABLE users RENAME COLUMN "long" TO "lng";
    END IF;
END $$;

-- 2. Rename 'long' to 'lng' in 'kitchens' table if it exists
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='kitchens' AND column_name='long') THEN
        ALTER TABLE kitchens RENAME COLUMN "long" TO "lng";
    END IF;
END $$;

-- 3. Rename 'long' to 'lng' in 'orders' table if it exists (for tracking_lng)
-- Note: OrderModel uses 'tracking_lng' but sometimes might use 'lng' in raw data
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='long') THEN
        ALTER TABLE orders RENAME COLUMN "long" TO "lng";
    END IF;
END $$;

-- 4. Rename 'long' to 'lng' in 'deliveries' table if it exists
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='deliveries' AND column_name='long') THEN
        ALTER TABLE deliveries RENAME COLUMN "long" TO "lng";
    END IF;
END $$;
