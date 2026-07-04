-- Confirm subscriptions allows pro plan and wallet payment method (idempotent)

ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_plan_type_check;
ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_plan_type_check
    CHECK (plan_type IN ('basic', 'pro', 'premium', 'enterprise'));

ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_payment_method_check;
ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_payment_method_check
    CHECK (payment_method IN ('card', 'etransfer', 'wallet'));
