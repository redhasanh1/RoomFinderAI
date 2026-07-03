-- Contact messages captured from the homepage "Get in Touch" form.
-- Acts as a durable fallback so messages are never lost if email delivery fails.

CREATE TABLE IF NOT EXISTS public.contact_messages (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  TEXT NOT NULL,
    last_name   TEXT,
    email       TEXT NOT NULL,
    message     TEXT NOT NULL,
    handled     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contact_messages_created_at
    ON public.contact_messages (created_at DESC);

-- Only the service role (backend) writes/reads these. Enable RLS with no public policies
-- so anon/authenticated clients cannot read submissions.
ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;
