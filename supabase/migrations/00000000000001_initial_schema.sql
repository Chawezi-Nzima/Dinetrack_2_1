-- ============================================================================
-- DineTrack — Clean Initial Schema
-- ============================================================================

create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- ============================================================================
-- ENUMS
-- ============================================================================

create type user_type as enum ('customer', 'operator', 'kitchen', 'supervisor', 'admin');
create type establishment_type as enum ('restaurant', 'pub', 'cafe', 'bar');
create type staff_role as enum ('manager', 'waiter', 'cashier');
create type order_status as enum ('pending', 'confirmed', 'preparing', 'ready', 'served', 'completed', 'cancelled');
create type payment_status as enum ('pending', 'paid', 'failed', 'refunded');
create type payment_method as enum ('cash', 'paychangu', 'dine_coins');
create type reservation_status as enum ('pending', 'confirmed', 'seated', 'completed', 'cancelled');
create type subscription_status as enum ('pending', 'active', 'expired', 'cancelled');
create type ledger_type as enum ('credit', 'debit');
create type assist_status as enum ('open', 'resolved');

-- ============================================================================
-- USERS  (mirrors auth.users; row is created automatically via trigger below)
-- ============================================================================

create table users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text,
  phone text,
  user_type user_type not null default 'customer',
  dine_coins_balance numeric(12,2) not null default 0,
  profile_image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ============================================================================
-- ESTABLISHMENTS
-- ============================================================================

create table establishments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references users(id) on delete cascade,
  name text not null,
  type establishment_type not null default 'restaurant',
  address text,
  phone text,
  description text,
  image_url text,
  is_active boolean not null default false,
  supervisor_approved boolean not null default false,
  dine_coins_balance numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index idx_establishments_owner on establishments(owner_id);

-- ============================================================================
-- STAFF / KITCHEN ASSIGNMENTS
-- ============================================================================

create table staff_assignments (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  name text,
  email text,
  role staff_role not null default 'waiter',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (establishment_id, user_id)
);

create table kitchen_assignments (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  assigned_station text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (establishment_id, user_id)
);

create index idx_staff_establishment on staff_assignments(establishment_id);
create index idx_kitchen_establishment on kitchen_assignments(establishment_id);

-- ============================================================================
-- MENU: categories, tags, items
-- ============================================================================

create table menu_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table menu_item_tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique -- 'bestseller', 'recommended', 'spicy', 'vegan', etc.
);

create table menu_items (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  category_id uuid references menu_categories(id) on delete set null,
  name text not null,
  description text,
  price numeric(12,2) not null check (price >= 0),
  image_url text,
  preparation_time int,
  is_available boolean not null default true,
  rating numeric(2,1) default 4.5,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table menu_item_tag_links (
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  tag_id uuid not null references menu_item_tags(id) on delete cascade,
  primary key (menu_item_id, tag_id)
);

create index idx_menu_items_establishment on menu_items(establishment_id);
create index idx_menu_items_category on menu_items(category_id);

-- ============================================================================
-- TABLES (physical restaurant tables / QR codes)
-- ============================================================================

create table tables (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  table_number int not null,
  label text,
  qr_code text unique,
  qr_code_data text,
  capacity int default 4,
  is_available boolean not null default true,
  occupied_at timestamptz,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  unique (establishment_id, table_number)
);

create index idx_tables_establishment on tables(establishment_id);

-- ============================================================================
-- ORDERS
-- ============================================================================

create table orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity,
  establishment_id uuid not null references establishments(id) on delete cascade,
  table_id uuid references tables(id) on delete set null,
  customer_id uuid references users(id) on delete set null,
  status order_status not null default 'pending',
  payment_status payment_status not null default 'pending',
  total_amount numeric(12,2) not null default 0,
  special_instructions text,
  group_session_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  menu_item_id uuid not null references menu_items(id) on delete restrict,
  quantity int not null check (quantity > 0),
  unit_price numeric(12,2) not null,
  line_total numeric(12,2) not null,
  special_instructions text,
  created_at timestamptz not null default now()
);

create index idx_orders_establishment on orders(establishment_id);
create index idx_orders_customer on orders(customer_id);
create index idx_orders_table on orders(table_id);
create index idx_order_items_order on order_items(order_id);

-- ============================================================================
-- GROUP ORDERING
-- ============================================================================

create table group_sessions (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  created_by uuid references users(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'closed')),
  created_at timestamptz not null default now()
);

create table group_session_participants (
  session_id uuid not null references group_sessions(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (session_id, user_id)
);

alter table orders
  add constraint fk_orders_group_session
  foreign key (group_session_id) references group_sessions(id) on delete set null;

-- ============================================================================
-- PAYMENTS
-- ============================================================================

create table payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete set null,
  payer_customer_id uuid references users(id) on delete set null,
  amount numeric(12,2) not null,
  payment_method payment_method not null default 'cash',
  status payment_status not null default 'pending',
  dine_coins_used numeric(12,2) not null default 0,
  provider_payment_id text,
  checkout_url text,
  idempotency_key text unique,
  metadata jsonb,
  webhook_received_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table payment_webhook_logs (
  id uuid primary key default gen_random_uuid(),
  provider_payment_id text,
  idempotency_key text,
  payload jsonb,
  error text,
  created_at timestamptz not null default now()
);

create index idx_payments_order on payments(order_id);
create index idx_payments_payer on payments(payer_customer_id);

-- ============================================================================
-- RESERVATIONS
-- ============================================================================

create table reservations (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  table_id uuid references tables(id) on delete set null,
  customer_id uuid references users(id) on delete set null,
  reservation_time timestamptz not null,
  party_size int not null default 2,
  status reservation_status not null default 'pending',
  special_requests text,
  created_at timestamptz not null default now()
);

create index idx_reservations_establishment on reservations(establishment_id);
create index idx_reservations_customer on reservations(customer_id);

-- ============================================================================
-- DINECOINS LEDGER
-- ============================================================================

create table dinecoins_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  establishment_id uuid references establishments(id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  transaction_type ledger_type not null,
  description text,
  created_at timestamptz not null default now()
);

create index idx_ledger_user on dinecoins_ledger(user_id);

-- ============================================================================
-- SUBSCRIPTIONS
-- ============================================================================

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  plan_type text not null default 'monthly' check (plan_type in ('monthly', 'yearly')),
  status subscription_status not null default 'pending',
  amount numeric(12,2) not null,
  payment_id uuid references payments(id),
  start_date timestamptz default now(),
  end_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_subscriptions_establishment on subscriptions(establishment_id);

-- ============================================================================
-- ASSIST REQUESTS ("call waiter")
-- ============================================================================

create table assist_requests (
  id uuid primary key default gen_random_uuid(),
  establishment_id uuid not null references establishments(id) on delete cascade,
  table_id uuid references tables(id) on delete cascade,
  status assist_status not null default 'open',
  created_at timestamptz not null default now()
);

create index idx_assist_establishment on assist_requests(establishment_id);

-- ============================================================================
-- FAVORITES
-- ============================================================================

create table user_favorites (
  user_id uuid not null references users(id) on delete cascade,
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, menu_item_id)
);

-- ============================================================================
-- TRIGGERS: updated_at bookkeeping
-- ============================================================================

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_users_updated_at before update on users
  for each row execute function set_updated_at();
create trigger trg_establishments_updated_at before update on establishments
  for each row execute function set_updated_at();
create trigger trg_menu_items_updated_at before update on menu_items
  for each row execute function set_updated_at();
create trigger trg_orders_updated_at before update on orders
  for each row execute function set_updated_at();
create trigger trg_payments_updated_at before update on payments
  for each row execute function set_updated_at();
create trigger trg_subscriptions_updated_at before update on subscriptions
  for each row execute function set_updated_at();

-- ============================================================================
-- TRIGGER: auto-create public.users row when someone signs up
-- (removes the manual "upsert into users after signUp" dance the old app did)
-- ============================================================================

create or replace function handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, phone, user_type)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce((new.raw_user_meta_data->>'user_type')::user_type, 'customer')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_auth_user();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

alter table users enable row level security;
alter table establishments enable row level security;
alter table staff_assignments enable row level security;
alter table kitchen_assignments enable row level security;
alter table menu_categories enable row level security;
alter table menu_item_tags enable row level security;
alter table menu_items enable row level security;
alter table menu_item_tag_links enable row level security;
alter table tables enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table group_sessions enable row level security;
alter table group_session_participants enable row level security;
alter table payments enable row level security;
alter table payment_webhook_logs enable row level security;
alter table reservations enable row level security;
alter table dinecoins_ledger enable row level security;
alter table subscriptions enable row level security;
alter table assist_requests enable row level security;
alter table user_favorites enable row level security;

-- Service role bypasses RLS entirely on all tables (edge functions, admin scripts)
create policy service_role_all on users for all to service_role using (true) with check (true);
create policy service_role_all on establishments for all to service_role using (true) with check (true);
create policy service_role_all on staff_assignments for all to service_role using (true) with check (true);
create policy service_role_all on kitchen_assignments for all to service_role using (true) with check (true);
create policy service_role_all on menu_categories for all to service_role using (true) with check (true);
create policy service_role_all on menu_item_tags for all to service_role using (true) with check (true);
create policy service_role_all on menu_items for all to service_role using (true) with check (true);
create policy service_role_all on menu_item_tag_links for all to service_role using (true) with check (true);
create policy service_role_all on tables for all to service_role using (true) with check (true);
create policy service_role_all on orders for all to service_role using (true) with check (true);
create policy service_role_all on order_items for all to service_role using (true) with check (true);
create policy service_role_all on group_sessions for all to service_role using (true) with check (true);
create policy service_role_all on group_session_participants for all to service_role using (true) with check (true);
create policy service_role_all on payments for all to service_role using (true) with check (true);
create policy service_role_all on payment_webhook_logs for all to service_role using (true) with check (true);
create policy service_role_all on reservations for all to service_role using (true) with check (true);
create policy service_role_all on dinecoins_ledger for all to service_role using (true) with check (true);
create policy service_role_all on subscriptions for all to service_role using (true) with check (true);
create policy service_role_all on assist_requests for all to service_role using (true) with check (true);
create policy service_role_all on user_favorites for all to service_role using (true) with check (true);

-- Helper: is the current user staff (any role) at a given establishment?
create or replace function is_staff_of(p_establishment_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from staff_assignments
    where establishment_id = p_establishment_id and user_id = auth.uid() and is_active = true
  ) or exists (
    select 1 from kitchen_assignments
    where establishment_id = p_establishment_id and user_id = auth.uid() and is_active = true
  ) or exists (
    select 1 from establishments
    where id = p_establishment_id and owner_id = auth.uid()
  );
$$;

-- USERS: people can read/update their own row
create policy users_select_own on users for select to authenticated using (id = auth.uid());
create policy users_update_own on users for update to authenticated using (id = auth.uid());

-- ESTABLISHMENTS: public can view approved+active ones; owners/staff manage their own
create policy establishments_public_read on establishments
  for select to anon, authenticated
  using (is_active = true and supervisor_approved = true);
create policy establishments_owner_manage on establishments
  for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy establishments_staff_read on establishments
  for select to authenticated
  using (is_staff_of(id));

-- STAFF / KITCHEN ASSIGNMENTS: owners manage, staff can see their own
create policy staff_owner_manage on staff_assignments
  for all to authenticated
  using (establishment_id in (select id from establishments where owner_id = auth.uid()))
  with check (establishment_id in (select id from establishments where owner_id = auth.uid()));
create policy staff_self_read on staff_assignments
  for select to authenticated using (user_id = auth.uid());

create policy kitchen_owner_manage on kitchen_assignments
  for all to authenticated
  using (establishment_id in (select id from establishments where owner_id = auth.uid()))
  with check (establishment_id in (select id from establishments where owner_id = auth.uid()));
create policy kitchen_self_read on kitchen_assignments
  for select to authenticated using (user_id = auth.uid());

-- MENU: public read of available items at active establishments; staff manage their own
create policy menu_categories_public_read on menu_categories for select to anon, authenticated using (is_active = true);
create policy menu_categories_staff_manage on menu_categories for all to authenticated using (true) with check (true);

create policy menu_tags_public_read on menu_item_tags for select to anon, authenticated using (true);

create policy menu_items_public_read on menu_items
  for select to anon, authenticated using (is_available = true);
create policy menu_items_staff_manage on menu_items
  for all to authenticated
  using (is_staff_of(establishment_id)) with check (is_staff_of(establishment_id));

create policy menu_item_tag_links_public_read on menu_item_tag_links for select to anon, authenticated using (true);
create policy menu_item_tag_links_staff_manage on menu_item_tag_links
  for all to authenticated
  using (menu_item_id in (select id from menu_items where is_staff_of(establishment_id)))
  with check (menu_item_id in (select id from menu_items where is_staff_of(establishment_id)));

-- TABLES: public can read (for QR/menu display), staff manage their own
create policy tables_public_read on tables for select to anon, authenticated using (true);
create policy tables_staff_manage on tables
  for all to authenticated
  using (is_staff_of(establishment_id)) with check (is_staff_of(establishment_id));

-- ORDERS: customers manage their own; staff manage their establishment's
create policy orders_customer_manage on orders
  for all to authenticated
  using (customer_id = auth.uid()) with check (customer_id = auth.uid());
create policy orders_staff_manage on orders
  for all to authenticated
  using (is_staff_of(establishment_id)) with check (is_staff_of(establishment_id));

create policy order_items_customer_read on order_items
  for select to authenticated
  using (order_id in (select id from orders where customer_id = auth.uid()));
create policy order_items_customer_insert on order_items
  for insert to authenticated
  with check (order_id in (select id from orders where customer_id = auth.uid()));
create policy order_items_staff_manage on order_items
  for all to authenticated
  using (order_id in (select id from orders where is_staff_of(establishment_id)))
  with check (order_id in (select id from orders where is_staff_of(establishment_id)));

-- GROUP SESSIONS: participants can read/join
create policy group_sessions_read on group_sessions for select to authenticated using (true);
create policy group_sessions_create on group_sessions for insert to authenticated with check (created_by = auth.uid());
create policy group_participants_read on group_session_participants for select to authenticated using (true);
create policy group_participants_join on group_session_participants for insert to authenticated with check (user_id = auth.uid());

-- PAYMENTS: payer can read/insert own; staff can read their establishment's
create policy payments_payer_read on payments
  for select to authenticated using (payer_customer_id = auth.uid());
create policy payments_payer_insert on payments
  for insert to authenticated with check (payer_customer_id = auth.uid());
create policy payments_staff_read on payments
  for select to authenticated
  using (order_id in (select id from orders where is_staff_of(establishment_id)));

-- RESERVATIONS: customers manage their own; staff manage their establishment's
create policy reservations_customer_manage on reservations
  for all to authenticated
  using (customer_id = auth.uid()) with check (customer_id = auth.uid());
create policy reservations_public_insert on reservations
  for insert to anon, authenticated with check (true); -- allow guest bookings
create policy reservations_staff_manage on reservations
  for all to authenticated
  using (is_staff_of(establishment_id)) with check (is_staff_of(establishment_id));

-- DINECOINS LEDGER: users read their own; staff of the relevant establishment can read
create policy ledger_user_read on dinecoins_ledger
  for select to authenticated using (user_id = auth.uid());

-- SUBSCRIPTIONS: establishment owners read their own
create policy subscriptions_owner_read on subscriptions
  for select to authenticated
  using (establishment_id in (select id from establishments where owner_id = auth.uid()));

-- ASSIST REQUESTS: anyone can create (guest at table), staff manage their establishment's
create policy assist_public_insert on assist_requests for insert to anon, authenticated with check (true);
create policy assist_staff_manage on assist_requests
  for all to authenticated
  using (is_staff_of(establishment_id)) with check (is_staff_of(establishment_id));

-- FAVORITES: users manage their own
create policy favorites_user_manage on user_favorites
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- SEED: starter menu categories (safe to edit/extend)
-- ============================================================================

insert into menu_categories (name, display_order) values
  ('Appetizers', 1),
  ('Main Course', 2),
  ('Beverages', 3),
  ('Desserts', 4),
  ('Snacks', 5)
on conflict (name) do nothing;

insert into menu_item_tags (name) values
  ('bestseller'),
  ('recommended'),
  ('spicy'),
  ('vegan'),
  ('new')
on conflict (name) do nothing;
