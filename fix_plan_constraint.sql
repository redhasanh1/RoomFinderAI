-- Fix the plan_type constraint to match frontend options
ALTER TABLE subscriptions DROP CONSTRAINT subscriptions_plan_type_check;
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_plan_type_check CHECK (plan_type IN ('basic', 'pro', 'premium'));