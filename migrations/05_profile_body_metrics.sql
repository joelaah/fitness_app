-- =============================================================================
-- Migration 05: Profile Body Metrics & BMR/TDEE Goals
-- =============================================================================
-- Target File: D:\fitness_app\migrations\05_profile_body_metrics.sql
-- 
-- Adds body metrics and metabolic profile attributes to public.profiles:
-- height_cm, weight_kg, age_years, biological_sex, activity_level, fitness_goal,
-- waist_cm, neck_cm, hip_cm.
-- =============================================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS height_cm NUMERIC CHECK (height_cm IS NULL OR (height_cm >= 50 AND height_cm <= 300)),
    ADD COLUMN IF NOT EXISTS weight_kg NUMERIC CHECK (weight_kg IS NULL OR (weight_kg >= 20 AND weight_kg <= 500)),
    ADD COLUMN IF NOT EXISTS age_years INTEGER CHECK (age_years IS NULL OR (age_years >= 10 AND age_years <= 120)),
    ADD COLUMN IF NOT EXISTS biological_sex TEXT CHECK (biological_sex IS NULL OR biological_sex IN ('male', 'female')),
    ADD COLUMN IF NOT EXISTS activity_level TEXT DEFAULT 'moderate'
        CHECK (activity_level IS NULL OR activity_level IN ('sedentary', 'light', 'moderate', 'active', 'athlete')),
    ADD COLUMN IF NOT EXISTS fitness_goal TEXT DEFAULT 'maintain'
        CHECK (fitness_goal IS NULL OR fitness_goal IN ('fat_loss', 'mild_cut', 'maintain', 'mild_bulk', 'bulking')),
    ADD COLUMN IF NOT EXISTS waist_cm NUMERIC CHECK (waist_cm IS NULL OR (waist_cm >= 30 AND waist_cm <= 250)),
    ADD COLUMN IF NOT EXISTS neck_cm NUMERIC CHECK (neck_cm IS NULL OR (neck_cm >= 15 AND neck_cm <= 100)),
    ADD COLUMN IF NOT EXISTS hip_cm NUMERIC CHECK (hip_cm IS NULL OR (hip_cm >= 30 AND hip_cm <= 250));
