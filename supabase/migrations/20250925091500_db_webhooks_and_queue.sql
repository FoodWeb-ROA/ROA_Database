-- Replace legacy pg_notify invalidation with HTTP webhooks and add parser queue
-- Ref: Supabase Database Webhooks https://supabase.com/docs/guides/database/webhooks

-- Safety: drop old trigger/function if present
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'notify_parser_cache_invalidation') THEN
    DROP FUNCTION IF EXISTS notify_parser_cache_invalidation() CASCADE;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DROP TRIGGER IF EXISTS trigger_cache_invalidation_recipes ON public.recipes;
DROP TRIGGER IF EXISTS trigger_cache_invalidation_recipe_components ON public.recipe_components;

-- App config for webhook URL/secret (simple key/value)
CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL
);

-- Insert placeholders if not present; update these in deployment
INSERT INTO public.app_config(key, value)
  VALUES
    ('db_webhook_url', 'https://YOUR_CLOUD_RUN_URL/webhooks/db'),
    ('db_webhook_secret', 'CHANGE_ME')
ON CONFLICT (key) DO NOTHING;

-- Helper: perform HTTP webhook with dynamic headers/payload
CREATE OR REPLACE FUNCTION public._send_parser_webhook(_payload jsonb)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  _url text;
  _secret text;
  _headers text;
BEGIN
  SELECT value INTO _url FROM public.app_config WHERE key = 'db_webhook_url' LIMIT 1;
  SELECT value INTO _secret FROM public.app_config WHERE key = 'db_webhook_secret' LIMIT 1;
  IF coalesce(_url, '') = '' THEN
    RAISE NOTICE 'db_webhook_url not configured; skipping webhook';
    RETURN;
  END IF;
  _headers := json_build_object(
    'Content-Type', 'application/json',
    'X-Webhook-Secret', coalesce(_secret, '')
  )::text;
  PERFORM supabase_functions.http_request(
    _url,
    'POST',
    _headers,
    _payload::text,
    '5000'
  );
END;
$$;

-- Generic trigger function to emit Database Webhook-compatible payload
CREATE OR REPLACE FUNCTION public.parser_db_webhook()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  _type text;
  _schema text := TG_TABLE_SCHEMA;
  _table text := TG_TABLE_NAME;
  _payload jsonb;
BEGIN
  _type := TG_OP; -- 'INSERT' | 'UPDATE' | 'DELETE'
  IF (_type = 'INSERT') THEN
    _payload := jsonb_build_object(
      'type', _type,
      'table', _table,
      'schema', _schema,
      'record', to_jsonb(NEW),
      'old_record', NULL
    );
  ELSIF (_type = 'UPDATE') THEN
    _payload := jsonb_build_object(
      'type', _type,
      'table', _table,
      'schema', _schema,
      'record', to_jsonb(NEW),
      'old_record', to_jsonb(OLD)
    );
  ELSE
    _payload := jsonb_build_object(
      'type', _type,
      'table', _table,
      'schema', _schema,
      'record', NULL,
      'old_record', to_jsonb(OLD)
    );
  END IF;

  PERFORM public._send_parser_webhook(_payload);
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Triggers for kitchen_categories (all changes)
DROP TRIGGER IF EXISTS webhook_kitchen_categories ON public.kitchen_categories;
CREATE TRIGGER webhook_kitchen_categories
AFTER INSERT OR UPDATE OR DELETE ON public.kitchen_categories
FOR EACH ROW EXECUTE FUNCTION public.parser_db_webhook();

-- Triggers for recipes (Preparations only)
DROP TRIGGER IF EXISTS webhook_recipes ON public.recipes;
CREATE TRIGGER webhook_recipes
AFTER INSERT OR UPDATE OR DELETE ON public.recipes
FOR EACH ROW WHEN (coalesce(NEW.recipe_type, OLD.recipe_type) = 'Preparation')
EXECUTE FUNCTION public.parser_db_webhook();

-- Triggers for recipe_components (always emit; filtering is handled in app)
DROP TRIGGER IF EXISTS webhook_recipe_components ON public.recipe_components;
CREATE TRIGGER webhook_recipe_components
AFTER INSERT OR UPDATE OR DELETE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.parser_db_webhook();

-- Parser request queue (optional usage)
CREATE TABLE IF NOT EXISTS public.parser_request_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  kitchen_id uuid NOT NULL,
  client_id text NOT NULL,
  files jsonb NOT NULL,
  status text NOT NULL DEFAULT 'received',
  error text
);

CREATE INDEX IF NOT EXISTS idx_parser_request_queue_kitchen_status ON public.parser_request_queue(kitchen_id, status);

-- Optional: basic RLS (adjust as needed)
ALTER TABLE public.parser_request_queue ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  PERFORM 1;
  -- Allow service role by policy (example; refine for your app)
  CREATE POLICY IF NOT EXISTS "service_read_write_queue" ON public.parser_request_queue
    FOR ALL USING (true) WITH CHECK (true);
EXCEPTION WHEN OTHERS THEN NULL; END $$;


