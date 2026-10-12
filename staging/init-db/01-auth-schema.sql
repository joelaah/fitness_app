-- =============================================================================
-- PulseFit AI Staging Database Bootstrap: Supabase Auth Emulation & Roles
-- =============================================================================
-- This script provisions the 'auth' schema, the 'auth.users' table, the
-- 'auth.uid()' function, and database roles required for local PostgreSQL 15
-- instances prior to executing 'supabase_schema.sql'.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create auth schema
CREATE SCHEMA IF NOT EXISTS auth;

-- 2. Create minimal auth.users table matching Supabase GoTrue contract
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE,
    encrypted_password TEXT,
    email_confirmed_at TIMESTAMPTZ DEFAULT NOW(),
    invited_at TIMESTAMPTZ,
    confirmation_token TEXT,
    confirmation_sent_at TIMESTAMPTZ,
    recovery_token TEXT,
    recovery_sent_at TIMESTAMPTZ,
    email_change_token_new TEXT,
    email_change TEXT,
    email_change_sent_at TIMESTAMPTZ,
    last_sign_in_at TIMESTAMPTZ,
    raw_app_meta_data JSONB DEFAULT '{"provider": "email", "providers": ["email"]}'::jsonb,
    raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
    is_super_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    phone TEXT,
    phone_confirmed_at TIMESTAMPTZ,
    phone_change TEXT,
    phone_change_token TEXT,
    phone_change_sent_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ DEFAULT NOW(),
    email_change_token_current TEXT,
    email_change_confirm_status SMALLINT DEFAULT 0,
    banned_until TIMESTAMPTZ,
    reauthentication_token TEXT,
    reauthentication_sent_at TIMESTAMPTZ,
    is_sso_user BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    is_anonymous BOOLEAN DEFAULT FALSE
);

-- 3. Mock auth.uid() function for RLS policy evaluation in PostgREST
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.role', true), '')::text;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth.email() RETURNS TEXT AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.email', true), '')::text;
$$ LANGUAGE sql STABLE;

-- 4. Create standard PostgREST / Supabase database roles if not existing
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'postgres';
    END IF;
END $$;

-- 5. Grant role inheritance to authenticator
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;

-- 6. Grant schema and table permissions
GRANT USAGE ON SCHEMA public, auth TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public, auth TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public, auth TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public, auth TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
