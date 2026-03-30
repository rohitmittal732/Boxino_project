-- ==========================================
-- 🛡️ Boxino: MASTER SYNC V7 (RPC FIX)
-- 🎯 Goal: Enable "NEW" Badge Logic.
-- ==========================================

-- 1. Create RPC for unrated kitchen count
CREATE OR REPLACE FUNCTION public.get_unrated_kitchen_count()
RETURNS integer AS $$
DECLARE
    u_id uuid;
    cnt integer;
BEGIN
    u_id := auth.uid();
    
    -- Count kitchens the user has ordered from (delivered) but hasn't rated yet
    SELECT COUNT(DISTINCT orders.kitchen_id) INTO cnt
    FROM public.orders
    LEFT JOIN public.ratings ON (
        ratings.kitchen_id = orders.kitchen_id 
        AND ratings.user_id = u_id
    )
    WHERE orders.user_id = u_id
    AND orders.status = 'delivered'
    AND ratings.id IS NULL; -- Joins fail to find a rating
    
    RETURN cnt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 🔥 V7 LOG: NEW badge logic backend is active.
