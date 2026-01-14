create type "public"."FoodClass" as enum ('Meat', 'Flour', 'Base', 'Spices');

create type "public"."StorageType" as enum ('Dry', 'Fresh', 'Prep');


  create table "public"."batches" (
    "created_at" timestamp with time zone not null default now(),
    "component_id" uuid not null,
    "batch_id" uuid not null default gen_random_uuid(),
    "amount" real not null,
    "amountunit" public.unit not null,
    "arrival_date" date not null,
    "is_expired" boolean not null,
    "supplier_id" uuid not null,
    "user_id" uuid not null
      );


alter table "public"."batches" enable row level security;


  create table "public"."orders" (
    "created_at" timestamp with time zone not null default now(),
    "supplier_id" uuid not null,
    "component_id" uuid not null default gen_random_uuid(),
    "user_id" uuid,
    "eta" interval not null,
    "order_id" uuid not null default gen_random_uuid()
      );


alter table "public"."orders" enable row level security;


  create table "public"."suppliers" (
    "supplier_id" uuid not null,
    "supplier_name" text not null,
    "supplier_email" text,
    "supplier_number" text
      );


alter table "public"."suppliers" enable row level security;

CREATE UNIQUE INDEX batches_batch_id_key ON public.batches USING btree (batch_id);

CREATE UNIQUE INDEX batches_pkey ON public.batches USING btree (batch_id, component_id);

CREATE UNIQUE INDEX orders_pkey ON public.orders USING btree (order_id, component_id);

CREATE UNIQUE INDEX suppliers_pkey ON public.suppliers USING btree (supplier_id);

CREATE UNIQUE INDEX suppliers_supplier_id_key ON public.suppliers USING btree (supplier_id);

alter table "public"."batches" add constraint "batches_pkey" PRIMARY KEY using index "batches_pkey";

alter table "public"."orders" add constraint "orders_pkey" PRIMARY KEY using index "orders_pkey";

alter table "public"."suppliers" add constraint "suppliers_pkey" PRIMARY KEY using index "suppliers_pkey";

alter table "public"."batches" add constraint "batches_batch_id_key" UNIQUE using index "batches_batch_id_key";

alter table "public"."batches" add constraint "batches_component_id_fkey" FOREIGN KEY (component_id) REFERENCES public.components(component_id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."batches" validate constraint "batches_component_id_fkey";

alter table "public"."batches" add constraint "batches_supplier_id_fkey" FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id) ON UPDATE CASCADE ON DELETE RESTRICT not valid;

alter table "public"."batches" validate constraint "batches_supplier_id_fkey";

alter table "public"."batches" add constraint "batches_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT not valid;

alter table "public"."batches" validate constraint "batches_user_id_fkey";

alter table "public"."orders" add constraint "orders_supplier_id_fkey" FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."orders" validate constraint "orders_supplier_id_fkey";

alter table "public"."orders" add constraint "orders_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT not valid;

alter table "public"."orders" validate constraint "orders_user_id_fkey";

alter table "public"."suppliers" add constraint "suppliers_supplier_id_key" UNIQUE using index "suppliers_supplier_id_key";

grant delete on table "public"."batches" to "anon";

grant insert on table "public"."batches" to "anon";

grant references on table "public"."batches" to "anon";

grant select on table "public"."batches" to "anon";

grant trigger on table "public"."batches" to "anon";

grant truncate on table "public"."batches" to "anon";

grant update on table "public"."batches" to "anon";

grant delete on table "public"."batches" to "authenticated";

grant insert on table "public"."batches" to "authenticated";

grant references on table "public"."batches" to "authenticated";

grant select on table "public"."batches" to "authenticated";

grant trigger on table "public"."batches" to "authenticated";

grant truncate on table "public"."batches" to "authenticated";

grant update on table "public"."batches" to "authenticated";

grant delete on table "public"."batches" to "service_role";

grant insert on table "public"."batches" to "service_role";

grant references on table "public"."batches" to "service_role";

grant select on table "public"."batches" to "service_role";

grant trigger on table "public"."batches" to "service_role";

grant truncate on table "public"."batches" to "service_role";

grant update on table "public"."batches" to "service_role";

grant delete on table "public"."orders" to "anon";

grant insert on table "public"."orders" to "anon";

grant references on table "public"."orders" to "anon";

grant select on table "public"."orders" to "anon";

grant trigger on table "public"."orders" to "anon";

grant truncate on table "public"."orders" to "anon";

grant update on table "public"."orders" to "anon";

grant delete on table "public"."orders" to "authenticated";

grant insert on table "public"."orders" to "authenticated";

grant references on table "public"."orders" to "authenticated";

grant select on table "public"."orders" to "authenticated";

grant trigger on table "public"."orders" to "authenticated";

grant truncate on table "public"."orders" to "authenticated";

grant update on table "public"."orders" to "authenticated";

grant delete on table "public"."orders" to "service_role";

grant insert on table "public"."orders" to "service_role";

grant references on table "public"."orders" to "service_role";

grant select on table "public"."orders" to "service_role";

grant trigger on table "public"."orders" to "service_role";

grant truncate on table "public"."orders" to "service_role";

grant update on table "public"."orders" to "service_role";

grant delete on table "public"."suppliers" to "anon";

grant insert on table "public"."suppliers" to "anon";

grant references on table "public"."suppliers" to "anon";

grant select on table "public"."suppliers" to "anon";

grant trigger on table "public"."suppliers" to "anon";

grant truncate on table "public"."suppliers" to "anon";

grant update on table "public"."suppliers" to "anon";

grant delete on table "public"."suppliers" to "authenticated";

grant insert on table "public"."suppliers" to "authenticated";

grant references on table "public"."suppliers" to "authenticated";

grant select on table "public"."suppliers" to "authenticated";

grant trigger on table "public"."suppliers" to "authenticated";

grant truncate on table "public"."suppliers" to "authenticated";

grant update on table "public"."suppliers" to "authenticated";

grant delete on table "public"."suppliers" to "service_role";

grant insert on table "public"."suppliers" to "service_role";

grant references on table "public"."suppliers" to "service_role";

grant select on table "public"."suppliers" to "service_role";

grant trigger on table "public"."suppliers" to "service_role";

grant truncate on table "public"."suppliers" to "service_role";

grant update on table "public"."suppliers" to "service_role";


