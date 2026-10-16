-- ========================================================================
-- PulseFit AI: Trainer Marketplace, Razorpay Payments & E2EE Realtime Chat
-- Database Migration 02: Marketplace, Payments & Chat Tables + RLS
-- Target: Supabase PostgreSQL 15+ / Local Staging PostgreSQL
-- ========================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------
-- Helper Trigger Function: Automated updated_at timestamps
-- ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------
-- 1. Profiles Table Interoperability Update (Additive SELECT Policy)
-- ------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'Authenticated users can view profiles'
    ) THEN
        CREATE POLICY "Authenticated users can view profiles"
            ON public.profiles FOR SELECT
            TO authenticated
            USING (true);
    END IF;
END $$;

-- ------------------------------------------------------------------------
-- 2. Trainer Profiles Table
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.trainer_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    bio TEXT DEFAULT '',
    certifications TEXT[] NOT NULL DEFAULT '{}'::text[],
    specialties TEXT[] NOT NULL DEFAULT '{}'::text[],
    experience_years INTEGER NOT NULL DEFAULT 0,
    hourly_rate NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    availability JSONB NOT NULL DEFAULT '{"schedule": [], "active": true}'::jsonb,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 5.00,
    platform_fee_pct NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
    verified BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT uq_trainer_profiles_user UNIQUE (user_id),
    CONSTRAINT ck_trainer_profiles_hourly_rate CHECK (hourly_rate >= 0.00),
    CONSTRAINT ck_trainer_profiles_experience CHECK (experience_years >= 0),
    CONSTRAINT ck_trainer_profiles_rating CHECK (rating >= 0.00 AND rating <= 5.00),
    CONSTRAINT ck_trainer_profiles_fee_pct CHECK (platform_fee_pct >= 0.00 AND platform_fee_pct <= 100.00)
);

-- Trigger: Sync verified and is_verified fields
CREATE OR REPLACE FUNCTION public.sync_trainer_verified()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.is_verified IS NOT NULL AND NEW.verified IS NULL THEN
            NEW.verified := NEW.is_verified;
        ELSIF NEW.verified IS NOT NULL AND NEW.is_verified IS NULL THEN
            NEW.is_verified := NEW.verified;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
            NEW.verified := NEW.is_verified;
        ELSIF NEW.verified IS DISTINCT FROM OLD.verified THEN
            NEW.is_verified := NEW.verified;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_trainer_verified ON public.trainer_profiles;
CREATE TRIGGER trg_sync_trainer_verified
    BEFORE INSERT OR UPDATE ON public.trainer_profiles
    FOR EACH ROW EXECUTE FUNCTION public.sync_trainer_verified();

-- Trigger: Prevent trainer profile privilege escalation (verified, fee, rating immutability)
CREATE OR REPLACE FUNCTION public.protect_trainer_profile_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF (coalesce(current_setting('role', true), '') <> 'service_role') THEN
        IF TG_OP = 'INSERT' THEN
            NEW.platform_fee_pct := 10.00;
            NEW.rating := 5.00;
            NEW.verified := TRUE;
            NEW.is_verified := TRUE;
        ELSIF TG_OP = 'UPDATE' THEN
            IF NEW.verified IS DISTINCT FROM OLD.verified THEN
                RAISE EXCEPTION 'Trainers cannot modify their own verification status.';
            END IF;
            IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
                RAISE EXCEPTION 'Trainers cannot modify their own verification status.';
            END IF;
            IF NEW.platform_fee_pct IS DISTINCT FROM OLD.platform_fee_pct THEN
                RAISE EXCEPTION 'Platform fee percentage is immutable by trainers.';
            END IF;
            IF NEW.rating IS DISTINCT FROM OLD.rating THEN
                RAISE EXCEPTION 'Rating cannot be directly updated.';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_trainer_profile_fields ON public.trainer_profiles;
CREATE TRIGGER trg_protect_trainer_profile_fields
    BEFORE INSERT OR UPDATE ON public.trainer_profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_trainer_profile_fields();

DROP TRIGGER IF EXISTS set_trainer_profiles_updated_at ON public.trainer_profiles;
CREATE TRIGGER set_trainer_profiles_updated_at
    BEFORE UPDATE ON public.trainer_profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.trainer_profiles ENABLE ROW LEVEL SECURITY;

-- Indexes for Trainer Profiles (Omitting redundant idx_trainer_profiles_user_id covered by uq_trainer_profiles_user)
CREATE INDEX IF NOT EXISTS idx_trainer_profiles_verified_rate
    ON public.trainer_profiles(verified, hourly_rate);
CREATE INDEX IF NOT EXISTS idx_trainer_profiles_specialties
    ON public.trainer_profiles USING GIN (specialties);
CREATE INDEX IF NOT EXISTS idx_trainer_profiles_rating
    ON public.trainer_profiles(rating DESC);

-- RLS Policies for Trainer Profiles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'trainer_profiles' AND policyname = 'Public can view trainer profiles') THEN
        CREATE POLICY "Public can view trainer profiles"
            ON public.trainer_profiles FOR SELECT
            USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'trainer_profiles' AND policyname = 'Users can insert own trainer profile') THEN
        CREATE POLICY "Users can insert own trainer profile"
            ON public.trainer_profiles FOR INSERT
            TO authenticated
            WITH CHECK ((select auth.uid()) = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'trainer_profiles' AND policyname = 'Trainers can update own profile') THEN
        CREATE POLICY "Trainers can update own profile"
            ON public.trainer_profiles FOR UPDATE
            TO authenticated
            USING ((select auth.uid()) = user_id)
            WITH CHECK ((select auth.uid()) = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'trainer_profiles' AND policyname = 'Trainers can delete own profile') THEN
        CREATE POLICY "Trainers can delete own profile"
            ON public.trainer_profiles FOR DELETE
            TO authenticated
            USING ((select auth.uid()) = user_id);
    END IF;
END $$;

-- ------------------------------------------------------------------------
-- 3. Encryption Keys Table (Public Keys for E2EE X25519)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.encryption_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    public_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT uq_encryption_keys_user UNIQUE (user_id),
    CONSTRAINT ck_encryption_keys_format CHECK (char_length(public_key) >= 40)
);

DROP TRIGGER IF EXISTS set_encryption_keys_updated_at ON public.encryption_keys;
CREATE TRIGGER set_encryption_keys_updated_at
    BEFORE UPDATE ON public.encryption_keys
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.encryption_keys ENABLE ROW LEVEL SECURITY;

-- Note: user_id index omitted as uq_encryption_keys_user creates a unique B-Tree index on user_id

-- RLS Policies for Encryption Keys
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'encryption_keys' AND policyname = 'Authenticated users can view public keys') THEN
        CREATE POLICY "Authenticated users can view public keys"
            ON public.encryption_keys FOR SELECT
            TO authenticated
            USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'encryption_keys' AND policyname = 'Users can insert own public key') THEN
        CREATE POLICY "Users can insert own public key"
            ON public.encryption_keys FOR INSERT
            TO authenticated
            WITH CHECK ((select auth.uid()) = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'encryption_keys' AND policyname = 'Users can update own public key') THEN
        CREATE POLICY "Users can update own public key"
            ON public.encryption_keys FOR UPDATE
            TO authenticated
            USING ((select auth.uid()) = user_id)
            WITH CHECK ((select auth.uid()) = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'encryption_keys' AND policyname = 'Users can delete own public key') THEN
        CREATE POLICY "Users can delete own public key"
            ON public.encryption_keys FOR DELETE
            TO authenticated
            USING ((select auth.uid()) = user_id);
    END IF;
END $$;

-- ------------------------------------------------------------------------
-- 4. Chat Conversations Table
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES public.trainer_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT uq_chat_conversation_pair UNIQUE (user_id, trainer_id)
);

DROP TRIGGER IF EXISTS set_chat_conversations_updated_at ON public.chat_conversations;
CREATE TRIGGER set_chat_conversations_updated_at
    BEFORE UPDATE ON public.chat_conversations
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_chat_conversations_user
    ON public.chat_conversations(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_trainer
    ON public.chat_conversations(trainer_id, updated_at DESC);

-- RLS Policies for Chat Conversations
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'chat_conversations' AND policyname = 'Participants can view conversation') THEN
        CREATE POLICY "Participants can view conversation"
            ON public.chat_conversations FOR SELECT
            TO authenticated
            USING (
                (select auth.uid()) = user_id
                OR
                EXISTS (
                    SELECT 1 FROM public.trainer_profiles tp
                    WHERE tp.id = chat_conversations.trainer_id
                    AND tp.user_id = (select auth.uid())
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'chat_conversations' AND policyname = 'Participants can insert conversation') THEN
        CREATE POLICY "Participants can insert conversation"
            ON public.chat_conversations FOR INSERT
            TO authenticated
            WITH CHECK (
                (select auth.uid()) = user_id
                OR
                EXISTS (
                    SELECT 1 FROM public.trainer_profiles tp
                    WHERE tp.id = chat_conversations.trainer_id
                    AND tp.user_id = (select auth.uid())
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'chat_conversations' AND policyname = 'Participants can update conversation') THEN
        CREATE POLICY "Participants can update conversation"
            ON public.chat_conversations FOR UPDATE
            TO authenticated
            USING (
                (select auth.uid()) = user_id
                OR
                EXISTS (
                    SELECT 1 FROM public.trainer_profiles tp
                    WHERE tp.id = chat_conversations.trainer_id
                    AND tp.user_id = (select auth.uid())
                )
            );
    END IF;
END $$;

-- ------------------------------------------------------------------------
-- 5. Chat Messages Table
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    client_uuid UUID NOT NULL,
    ciphertext TEXT NOT NULL,
    nonce TEXT NOT NULL,
    mac TEXT DEFAULT '',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT uq_chat_messages_client_uuid UNIQUE (client_uuid),
    CONSTRAINT ck_chat_messages_nonce CHECK (char_length(nonce) >= 12)
);

-- Trigger: Sync is_read and read_at
CREATE OR REPLACE FUNCTION public.sync_chat_message_read()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.read_at IS NOT NULL AND NEW.is_read = FALSE THEN
        NEW.is_read := TRUE;
    ELSIF NEW.is_read = TRUE AND NEW.read_at IS NULL THEN
        NEW.read_at := TIMEZONE('utc'::text, NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_chat_message_read ON public.chat_messages;
CREATE TRIGGER trg_sync_chat_message_read
    BEFORE INSERT OR UPDATE ON public.chat_messages
    FOR EACH ROW EXECUTE FUNCTION public.sync_chat_message_read();

-- Trigger: Chat Message Tamper Protection (Immutable content, nonce, mac, and metadata)
CREATE OR REPLACE FUNCTION public.protect_chat_message_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF (coalesce(current_setting('role', true), '') <> 'service_role') THEN
        IF NEW.ciphertext IS DISTINCT FROM OLD.ciphertext OR 
           NEW.nonce IS DISTINCT FROM OLD.nonce OR 
           NEW.mac IS DISTINCT FROM OLD.mac OR 
           NEW.client_uuid IS DISTINCT FROM OLD.client_uuid OR 
           NEW.conversation_id IS DISTINCT FROM OLD.conversation_id OR 
           NEW.sender_id IS DISTINCT FROM OLD.sender_id OR 
           NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'Chat message content, nonce, mac, and metadata are strictly immutable.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_chat_message_immutability ON public.chat_messages;
CREATE TRIGGER trg_protect_chat_message_immutability
    BEFORE UPDATE ON public.chat_messages
    FOR EACH ROW EXECUTE FUNCTION public.protect_chat_message_immutability();

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Indexes for Chat Messages (Omitting redundant idx_chat_messages_client_uuid covered by uq_chat_messages_client_uuid)
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
    ON public.chat_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender
    ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread
    ON public.chat_messages(conversation_id, read_at)
    WHERE read_at IS NULL;

-- RLS Policies for Chat Messages
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'chat_messages' AND policyname = 'Participants can view messages') THEN
        CREATE POLICY "Participants can view messages"
            ON public.chat_messages FOR SELECT
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.chat_conversations c
                    JOIN public.trainer_profiles tp ON tp.id = c.trainer_id
                    WHERE c.id = chat_messages.conversation_id
                    AND (c.user_id = (select auth.uid()) OR tp.user_id = (select auth.uid()))
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'chat_messages' AND policyname = 'Participants can insert own message') THEN
        CREATE POLICY "Participants can insert own message"
            ON public.chat_messages FOR INSERT
            TO authenticated
            WITH CHECK (
                (select auth.uid()) = sender_id
                AND
                EXISTS (
                    SELECT 1 FROM public.chat_conversations c
                    JOIN public.trainer_profiles tp ON tp.id = c.trainer_id
                    WHERE c.id = chat_messages.conversation_id
                    AND (c.user_id = (select auth.uid()) OR tp.user_id = (select auth.uid()))
                )
            );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'chat_messages' AND policyname = 'Participants can update message read_at') THEN
        CREATE POLICY "Participants can update message read_at"
            ON public.chat_messages FOR UPDATE
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.chat_conversations c
                    JOIN public.trainer_profiles tp ON tp.id = c.trainer_id
                    WHERE c.id = chat_messages.conversation_id
                    AND (c.user_id = (select auth.uid()) OR tp.user_id = (select auth.uid()))
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.chat_conversations c
                    JOIN public.trainer_profiles tp ON tp.id = c.trainer_id
                    WHERE c.id = chat_messages.conversation_id
                    AND (c.user_id = (select auth.uid()) OR tp.user_id = (select auth.uid()))
                )
            );
    END IF;
END $$;

-- ------------------------------------------------------------------------
-- 6. Payment Transactions Table
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idempotency_key TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    trainer_id UUID NOT NULL REFERENCES public.trainer_profiles(id) ON DELETE RESTRICT,
    order_id TEXT NOT NULL,
    razorpay_order_id TEXT,
    payment_id TEXT,
    razorpay_payment_id TEXT,
    razorpay_signature TEXT,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    platform_fee NUMERIC(10, 2) NOT NULL,
    platform_fee_amount NUMERIC(10, 2),
    platform_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
    trainer_amount NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'created',
    metadata JSONB DEFAULT '{}'::jsonb,
    encrypted_metadata TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    CONSTRAINT uq_payment_transactions_idempotency UNIQUE (idempotency_key),
    CONSTRAINT ck_payment_amount_positive CHECK (amount > 0.00),
    CONSTRAINT ck_payment_fee_non_negative CHECK (platform_fee >= 0.00),
    CONSTRAINT ck_trainer_amount_non_negative CHECK (trainer_amount >= 0.00),
    CONSTRAINT ck_payment_amount_split CHECK (amount = platform_fee + trainer_amount),
    CONSTRAINT ck_payment_status CHECK (status IN ('created', 'authorized', 'captured', 'failed', 'refunded'))
);

-- Trigger: Synchronize order_id <-> razorpay_order_id, payment_id <-> razorpay_payment_id, fee fields
CREATE OR REPLACE FUNCTION public.sync_payment_transaction_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync order_id and razorpay_order_id
    IF NEW.order_id IS NOT NULL AND NEW.razorpay_order_id IS NULL THEN
        NEW.razorpay_order_id := NEW.order_id;
    ELSIF NEW.razorpay_order_id IS NOT NULL AND NEW.order_id IS NULL THEN
        NEW.order_id := NEW.razorpay_order_id;
    END IF;

    -- Sync payment_id and razorpay_payment_id
    IF NEW.payment_id IS NOT NULL AND NEW.razorpay_payment_id IS NULL THEN
        NEW.razorpay_payment_id := NEW.payment_id;
    ELSIF NEW.razorpay_payment_id IS NOT NULL AND NEW.payment_id IS NULL THEN
        NEW.payment_id := NEW.razorpay_payment_id;
    END IF;

    -- Sync platform_fee and platform_fee_amount
    IF NEW.platform_fee IS NOT NULL AND NEW.platform_fee_amount IS NULL THEN
        NEW.platform_fee_amount := NEW.platform_fee;
    ELSIF NEW.platform_fee_amount IS NOT NULL AND NEW.platform_fee IS NULL THEN
        NEW.platform_fee := NEW.platform_fee_amount;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_payment_transaction_fields ON public.payment_transactions;
CREATE TRIGGER trg_sync_payment_transaction_fields
    BEFORE INSERT OR UPDATE ON public.payment_transactions
    FOR EACH ROW EXECUTE FUNCTION public.sync_payment_transaction_fields();

DROP TRIGGER IF EXISTS set_payment_transactions_updated_at ON public.payment_transactions;
CREATE TRIGGER set_payment_transactions_updated_at
    BEFORE UPDATE ON public.payment_transactions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

-- Indexes for Payment Transactions (Omitting redundant idx_payment_transactions_idempotency covered by uq_payment_transactions_idempotency)
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user
    ON public.payment_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_trainer
    ON public.payment_transactions(trainer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order
    ON public.payment_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status
    ON public.payment_transactions(status);

-- RLS Policies for Payment Transactions
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'payment_transactions' AND policyname = 'Users and trainers can view own transactions') THEN
        CREATE POLICY "Users and trainers can view own transactions"
            ON public.payment_transactions FOR SELECT
            TO authenticated
            USING (
                (select auth.uid()) = user_id
                OR
                EXISTS (
                    SELECT 1 FROM public.trainer_profiles tp
                    WHERE tp.id = payment_transactions.trainer_id
                    AND tp.user_id = (select auth.uid())
                )
            );
    END IF;

    DROP POLICY IF EXISTS "Users can insert payment transactions" ON public.payment_transactions;
    CREATE POLICY "Users can insert payment transactions"
        ON public.payment_transactions FOR INSERT
        TO authenticated
        WITH CHECK ((select auth.uid()) = user_id AND status = 'created');

    DROP POLICY IF EXISTS "Users can update pending transaction" ON public.payment_transactions;
    CREATE POLICY "Users can update pending transaction"
        ON public.payment_transactions FOR UPDATE
        TO authenticated
        USING ((select auth.uid()) = user_id AND status = 'created')
        WITH CHECK ((select auth.uid()) = user_id AND status = 'created');
END $$;

-- ------------------------------------------------------------------------
-- 7. Supabase Realtime Publication & Replica Identity
-- ------------------------------------------------------------------------
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.chat_conversations REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations;
    END IF;
END $$;
