-- =============================================================================
-- Migration 03: Anonymous Session Lifecycle & 2-Hour Auto-Expiry Policy
-- =============================================================================
-- Implements automated lifecycle management for anonymous guest sessions:
-- 1. Adds 2-hour TTL tagging to profiles and partial index on auth.users.
-- 2. Provides testable functions to identify and purge expired anonymous sessions.
-- 3. Guarantees permanent registered accounts remain completely unaffected.
-- 4. Registers automated hourly cron task if pg_cron extension is available.
-- =============================================================================

-- 1. Ensure is_anonymous column exists in auth.users
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'auth' AND table_name = 'users' AND column_name = 'is_anonymous'
    ) THEN
        ALTER TABLE auth.users ADD COLUMN is_anonymous BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 2. Partial index on anonymous users created_at for fast expiry queries
CREATE INDEX IF NOT EXISTS idx_auth_users_anon_created_at
    ON auth.users(created_at)
    WHERE is_anonymous IS TRUE;

-- 3. Extend public.profiles with TTL tracking and anonymous status
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_expires_at
    ON public.profiles(expires_at)
    WHERE is_anonymous IS TRUE;

-- 4. Trigger to tag profiles with 2-hour TTL window for anonymous accounts
CREATE OR REPLACE FUNCTION public.tag_anonymous_profile_ttl()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    user_is_anon BOOLEAN;
BEGIN
    -- If explicitly marked as permanent in the update/insert, honor it
    IF NEW.is_anonymous IS FALSE THEN
        NEW.expires_at := NULL;
        RETURN NEW;
    END IF;

    SELECT is_anonymous INTO user_is_anon
    FROM auth.users
    WHERE id = NEW.id;

    IF user_is_anon IS TRUE THEN
        NEW.is_anonymous := TRUE;
        IF NEW.expires_at IS NULL THEN
            NEW.expires_at := TIMEZONE('utc'::text, NOW()) + INTERVAL '2 hours';
        END IF;
    ELSE
        -- When upgraded to a permanent account, clear guest TTL
        NEW.is_anonymous := FALSE;
        NEW.expires_at := NULL;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tag_anonymous_profile_ttl ON public.profiles;
CREATE TRIGGER trg_tag_anonymous_profile_ttl
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.tag_anonymous_profile_ttl();

-- 5. Testable function: Identify expired anonymous users
-- Returns all anonymous users created more than `cutoff_interval` ago (default: 2 hours).
-- Permanent users (is_anonymous = FALSE or NULL) are strictly excluded.
CREATE OR REPLACE FUNCTION public.get_expired_anonymous_users(
    cutoff_interval INTERVAL DEFAULT INTERVAL '2 hours'
)
RETURNS TABLE (
    user_id UUID,
    created_at TIMESTAMPTZ,
    is_anonymous BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = auth, public, pg_temp
AS $$
    SELECT id AS user_id, created_at, is_anonymous
    FROM auth.users
    WHERE is_anonymous IS TRUE
      AND created_at < (TIMEZONE('utc'::text, NOW()) - cutoff_interval);
$$;

-- 6. Testable function: Purge expired anonymous users and orphaned data
-- Purges anonymous accounts older than `cutoff_interval` (default: 2 hours)
-- Cascades through all dependent user records (profiles, workout sessions, chat, etc.).
-- Never affects permanent accounts.
CREATE OR REPLACE FUNCTION public.purge_expired_anonymous_users(
    cutoff_interval INTERVAL DEFAULT INTERVAL '2 hours'
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    purged_count INTEGER := 0;
    expired_ids UUID[];
BEGIN
    -- 1. Identify anonymous users strictly older than the cutoff interval
    SELECT array_agg(id)
    INTO expired_ids
    FROM auth.users
    WHERE is_anonymous IS TRUE
      AND created_at < (TIMEZONE('utc'::text, NOW()) - cutoff_interval);

    IF expired_ids IS NULL OR array_length(expired_ids, 1) IS NULL THEN
        RETURN 0;
    END IF;

    -- 2. Explicitly remove any dependent rows with RESTRICT constraints
    DELETE FROM public.payment_transactions
    WHERE user_id = ANY(expired_ids)
       OR trainer_id IN (SELECT id FROM public.trainer_profiles WHERE user_id = ANY(expired_ids));

    -- 3. Delete from auth.users (cascades to profiles, workout_sessions, workout_exercises,
    --    workout_sets, ai_recommendations, encryption_keys, chat_conversations, chat_messages)
    WITH deleted_users AS (
        DELETE FROM auth.users
        WHERE id = ANY(expired_ids)
          AND is_anonymous IS TRUE -- Invariant defense check
        RETURNING id
    )
    SELECT count(*)::INTEGER INTO purged_count FROM deleted_users;

    -- 4. Clean up any decoupled or orphaned profile rows
    DELETE FROM public.profiles
    WHERE id = ANY(expired_ids)
       OR (is_anonymous IS TRUE AND expires_at < (TIMEZONE('utc'::text, NOW()) - cutoff_interval));

    RETURN purged_count;
END;
$$;

-- 7. Permissions
GRANT EXECUTE ON FUNCTION public.tag_anonymous_profile_ttl() TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.get_expired_anonymous_users(INTERVAL) TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.purge_expired_anonymous_users(INTERVAL) TO authenticated, service_role, postgres;

-- 8. Automated hourly schedule via pg_cron (if extension enabled)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.unschedule('purge-expired-anonymous-users')
        WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'purge-expired-anonymous-users');

        PERFORM cron.schedule(
            'purge-expired-anonymous-users',
            '0 * * * *',
            'SELECT public.purge_expired_anonymous_users();'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;
