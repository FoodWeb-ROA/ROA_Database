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

-- Using direct supabase_functions.http_request triggers so they appear in the Webhooks UI

-- Trigger for categories (if used globally)
DROP TRIGGER IF EXISTS webhook_categories ON public.categories;
CREATE TRIGGER webhook_categories
AFTER INSERT OR UPDATE OR DELETE ON public.categories
FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(
  'https://docparse-staging-515418725737.us-central1.run.app/webhooks/db',
  'POST',
  '{"Content-Type":"application/json","X-Webhook-Secret":"roa-parser-update-webhook"}',
  '{}',
  '5000'
);

-- Trigger for recipes (all events; app filters Preparation-only)
DROP TRIGGER IF EXISTS webhook_recipes_insupd ON public.recipes;
DROP TRIGGER IF EXISTS webhook_recipes_del ON public.recipes;
DROP TRIGGER IF EXISTS webhook_recipes ON public.recipes;
CREATE TRIGGER webhook_recipes
AFTER INSERT OR UPDATE OR DELETE ON public.recipes
FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(
  'https://docparse-staging-515418725737.us-central1.run.app/webhooks/db',
  'POST',
  '{"Content-Type":"application/json","X-Webhook-Secret":"roa-parser-update-webhook"}',
  '{}',
  '5000'
);

-- Trigger for recipe_components (always emit; filtering is handled in app)
DROP TRIGGER IF EXISTS webhook_recipe_components ON public.recipe_components;
CREATE TRIGGER webhook_recipe_components
AFTER INSERT OR UPDATE OR DELETE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(
  'https://docparse-staging-515418725737.us-central1.run.app/webhooks/db',
  'POST',
  '{"Content-Type":"application/json","X-Webhook-Secret":"roa-parser-update-webhook"}',
  '{}',
  '5000'
);

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


