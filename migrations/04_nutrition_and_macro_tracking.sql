-- =============================================================================
-- Migration 04: Nutrition & Macro Tracking with Multi-Tenant Row Level Security
-- =============================================================================
-- Target File: D:\fitness_app\migrations\04_nutrition_and_macro_tracking.sql
-- 
-- Implements:
-- 1. Daily macro targets on public.profiles (calories, protein, carbs, fat, preferences).
-- 2. public.nutrition_logs table with JSONB itemized food breakdown and Atwater metrics.
-- 3. Multi-tenant Row Level Security (RLS) guaranteeing strict isolation per auth.uid().
-- 4. High-performance composite indexes for daily aggregation queries.
-- 5. Helper SQL functions for deterministic daily macro rollups.
-- =============================================================================

-- 1. Extend public.profiles with customizable macronutrient targets
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS target_calories INTEGER DEFAULT 2000 CHECK (target_calories >= 500 AND target_calories <= 10000),
    ADD COLUMN IF NOT EXISTS target_protein_g INTEGER DEFAULT 150 CHECK (target_protein_g >= 0 AND target_protein_g <= 1000),
    ADD COLUMN IF NOT EXISTS target_carbs_g INTEGER DEFAULT 200 CHECK (target_carbs_g >= 0 AND target_carbs_g <= 2000),
    ADD COLUMN IF NOT EXISTS target_fat_g INTEGER DEFAULT 65 CHECK (target_fat_g >= 0 AND target_fat_g <= 1000),
    ADD COLUMN IF NOT EXISTS dietary_preference TEXT DEFAULT 'balanced';

-- 2. Create public.nutrition_logs table
CREATE TABLE IF NOT EXISTS public.nutrition_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    meal_name TEXT NOT NULL,
    meal_type TEXT NOT NULL DEFAULT 'other' CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack', 'other')),
    image_url TEXT,
    logged_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    total_calories NUMERIC NOT NULL DEFAULT 0 CHECK (total_calories >= 0),
    total_protein_g NUMERIC NOT NULL DEFAULT 0 CHECK (total_protein_g >= 0),
    total_carbs_g NUMERIC NOT NULL DEFAULT 0 CHECK (total_carbs_g >= 0),
    total_fat_g NUMERIC NOT NULL DEFAULT 0 CHECK (total_fat_g >= 0),
    atwater_calories NUMERIC CHECK (atwater_calories IS NULL OR atwater_calories >= 0),
    items_json JSONB DEFAULT '[]'::jsonb NOT NULL,
    health_score INTEGER CHECK (health_score IS NULL OR (health_score >= 0 AND health_score <= 100)),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;

-- 4. Multi-Tenant RLS Policies (Strict User Isolation)
DROP POLICY IF EXISTS "Users can view own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can view own nutrition logs"
    ON public.nutrition_logs FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can insert own nutrition logs"
    ON public.nutrition_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can update own nutrition logs"
    ON public.nutrition_logs FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own nutrition logs" ON public.nutrition_logs;
CREATE POLICY "Users can delete own nutrition logs"
    ON public.nutrition_logs FOR DELETE
    USING (auth.uid() = user_id);

-- 5. Optimized Performance Indexes
CREATE INDEX IF NOT EXISTS idx_nutrition_logs_user_logged_at
    ON public.nutrition_logs(user_id, logged_at DESC);

CREATE INDEX IF NOT EXISTS idx_nutrition_logs_meal_type
    ON public.nutrition_logs(user_id, meal_type);

CREATE INDEX IF NOT EXISTS idx_nutrition_logs_items_gin
    ON public.nutrition_logs USING GIN (items_json);

-- 6. Trigger to automatically refresh updated_at
CREATE OR REPLACE FUNCTION public.handle_nutrition_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_nutrition_logs_updated_at ON public.nutrition_logs;
CREATE TRIGGER trg_nutrition_logs_updated_at
    BEFORE UPDATE ON public.nutrition_logs
    FOR EACH ROW EXECUTE FUNCTION public.handle_nutrition_updated_at();

-- 7. Deterministic Daily Macro Rollup Function
CREATE OR REPLACE FUNCTION public.get_daily_macro_summary(
    p_user_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    logged_date DATE,
    meal_count BIGINT,
    total_calories NUMERIC,
    total_protein_g NUMERIC,
    total_carbs_g NUMERIC,
    total_fat_g NUMERIC,
    target_calories INTEGER,
    target_protein_g INTEGER,
    target_carbs_g INTEGER,
    target_fat_g INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_target_cal INTEGER := 2000;
    v_target_p INTEGER := 150;
    v_target_c INTEGER := 200;
    v_target_f INTEGER := 65;
BEGIN
    -- Query user's macro target configuration
    SELECT
        COALESCE(p.target_calories, 2000),
        COALESCE(p.target_protein_g, 150),
        COALESCE(p.target_carbs_g, 200),
        COALESCE(p.target_fat_g, 65)
    INTO
        v_target_cal, v_target_p, v_target_c, v_target_f
    FROM public.profiles p
    WHERE p.id = p_user_id;

    RETURN QUERY
    SELECT
        p_date AS logged_date,
        COUNT(n.id) AS meal_count,
        COALESCE(SUM(n.total_calories), 0)::NUMERIC AS total_calories,
        COALESCE(SUM(n.total_protein_g), 0)::NUMERIC AS total_protein_g,
        COALESCE(SUM(n.total_carbs_g), 0)::NUMERIC AS total_carbs_g,
        COALESCE(SUM(n.total_fat_g), 0)::NUMERIC AS total_fat_g,
        v_target_cal AS target_calories,
        v_target_p AS target_protein_g,
        v_target_c AS target_carbs_g,
        v_target_f AS target_fat_g
    FROM public.nutrition_logs n
    WHERE n.user_id = p_user_id
      AND DATE(n.logged_at AT TIME ZONE 'UTC') = p_date;
END;
$$;
