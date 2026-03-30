-- ==========================================
-- 🛡️ Boxino: PRODUCTION RATINGS PATCH V6
-- 🎯 Goal: Automated Social Proof & Rating Sync.
-- ==========================================

-- 1. Create Ratings Table
CREATE TABLE IF NOT EXISTS public.ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  kitchen_id uuid REFERENCES public.kitchens(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  feedback text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, kitchen_id) -- One rating per user per kitchen
);

-- 2. Add rating_avg to kitchens table
ALTER TABLE public.kitchens ADD COLUMN IF NOT EXISTS rating_avg numeric(3,2) DEFAULT 0;
ALTER TABLE public.kitchens ADD COLUMN IF NOT EXISTS total_reviews integer DEFAULT 0;

-- 3. Automatic Average Trigger
CREATE OR REPLACE FUNCTION public.update_kitchen_rating_stats()
RETURNS trigger AS $$
BEGIN
  -- If rating is inserted, updated, or deleted
  UPDATE public.kitchens
  SET 
    rating_avg = (
      SELECT COALESCE(AVG(rating), 0)
      FROM public.ratings
      WHERE kitchen_id = COALESCE(NEW.kitchen_id, OLD.kitchen_id)
    ),
    total_reviews = (
      SELECT COUNT(*)
      FROM public.ratings
      WHERE kitchen_id = COALESCE(NEW.kitchen_id, OLD.kitchen_id)
    )
  WHERE id = COALESCE(NEW.kitchen_id, OLD.kitchen_id);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Attach Trigger
DROP TRIGGER IF EXISTS tr_update_kitchen_rating ON public.ratings;
CREATE TRIGGER tr_update_kitchen_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.ratings
  FOR EACH ROW EXECUTE PROCEDURE public.update_kitchen_rating_stats();

-- 5. RLS Policies
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can rate kitchens" ON ratings;
CREATE POLICY "Users can rate kitchens"
ON ratings FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their rating" ON ratings;
CREATE POLICY "Users can update their rating"
ON ratings FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view ratings" ON ratings;
CREATE POLICY "Anyone can view ratings"
ON ratings FOR SELECT
TO authenticated
USING (true);

-- 🔥 V6 LOG: Social proof engine active.
