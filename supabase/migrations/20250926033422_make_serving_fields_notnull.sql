-- Backfill null values before making columns NOT NULL
UPDATE recipes 
SET serving_or_yield_amount = 1, 
    serving_or_yield_unit = 'x'
WHERE serving_or_yield_amount IS NULL OR serving_or_yield_unit IS NULL;

ALTER TABLE recipes ALTER COLUMN serving_or_yield_amount SET NOT NULL;
ALTER TABLE recipes ALTER COLUMN serving_or_yield_unit SET NOT NULL;