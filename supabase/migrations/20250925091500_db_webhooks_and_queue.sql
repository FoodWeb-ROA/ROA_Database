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

-- NOTE: Enter your actual webhook URL and secret directly inside parser_db_webhook() below.

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
  _url text := 'https://docparse-staging-515418725737.us-central1.run.app/webhooks/db';
  _secret text := 'roa-parser-update-webhook';
  _headers text;
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
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Triggers for categories (all changes)
DROP TRIGGER IF EXISTS webhook_categories ON public.categories;
CREATE TRIGGER webhook_categories
AFTER INSERT OR UPDATE OR DELETE ON public.categories
FOR EACH ROW EXECUTE FUNCTION public.parser_db_webhook();

-- Triggers for recipes (Preparations only) – split to avoid NEW in DELETE
DROP TRIGGER IF EXISTS webhook_recipes_insupd ON public.recipes;
CREATE TRIGGER webhook_recipes_insupd
AFTER INSERT OR UPDATE ON public.recipes
FOR EACH ROW WHEN (NEW.recipe_type = 'Preparation')
EXECUTE FUNCTION public.parser_db_webhook();

DROP TRIGGER IF EXISTS webhook_recipes_del ON public.recipes;
CREATE TRIGGER webhook_recipes_del
AFTER DELETE ON public.recipes
FOR EACH ROW WHEN (OLD.recipe_type = 'Preparation')
EXECUTE FUNCTION public.parser_db_webhook();

-- Triggers for recipe_components (always emit; filtering is handled in app)
DROP TRIGGER IF EXISTS webhook_recipe_components ON public.recipe_components;
CREATE TRIGGER webhook_recipe_components
AFTER INSERT OR UPDATE OR DELETE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.parser_db_webhook();

-- Parser request queue 
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

-- RLS: only service_role can access the queue
ALTER TABLE public.parser_request_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service_read_write_queue" ON public.parser_request_queue;
CREATE POLICY "service_read_write_queue" ON public.parser_request_queue
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


