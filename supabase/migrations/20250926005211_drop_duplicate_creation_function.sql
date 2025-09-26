DROP FUNCTION IF EXISTS public.create_preparation_with_component(
  _kitchen uuid,
  _name text,
  _category uuid,
  _directions text[],
  _time interval,
  _cooking_notes text
);