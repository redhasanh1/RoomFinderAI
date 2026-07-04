-- Pro membership flag on profiles (set by Stripe webhook)

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_pro BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'free';

COMMENT ON COLUMN public.profiles.is_pro IS 'True when user has active Pro subscription';
COMMENT ON COLUMN public.profiles.plan IS 'free | pro';
