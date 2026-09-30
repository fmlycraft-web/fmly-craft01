create extension if not exists postgis;
create type public.app_role as enum ('customer','owner','rider');
create type public.rider_state as enum ('pending','approved','rejected','suspended');
create type public.order_status as enum ('pending','confirmed','preparing','ready_for_pickup','assigned','picked_up','out_for_delivery','delivered','cancelled');
create type public.payment_status as enum ('pending','processing','paid','failed','refunded','cancelled');

create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text, phone text, role public.app_role not null default 'customer', avatar_url text, created_at timestamptz default now(), updated_at timestamptz default now());
create table public.categories (id uuid primary key default gen_random_uuid(), name text not null unique, image_url text, sort_order int default 0, is_active boolean default true, created_at timestamptz default now());
create table public.subcategories (id uuid primary key default gen_random_uuid(), category_id uuid references categories(id) on delete cascade, name text not null, sort_order int default 0, is_active boolean default true);
create table public.products (id uuid primary key default gen_random_uuid(), name text not null, slug text unique not null, description text default '', category_id uuid references categories(id), subcategory_id uuid references subcategories(id), price numeric(12,2) not null check(price>=0), mrp numeric(12,2) not null check(mrp>=0), sku text unique, stock_quantity int not null default 0 check(stock_quantity>=0), is_active boolean default true, is_featured boolean default false, is_popular boolean default false, is_new_arrival boolean default false, rating numeric(3,2) default 0, review_count int default 0, created_at timestamptz default now(), updated_at timestamptz default now());
create table public.product_images (id uuid primary key default gen_random_uuid(), product_id uuid references products(id) on delete cascade, url text not null, sort_order int default 0, is_primary boolean default false);
create table public.addresses (id uuid primary key default gen_random_uuid(), user_id uuid references profiles(id) on delete cascade not null, full_name text not null, mobile text not null, address_type text not null, sector_area text not null, house_flat text not null, landmark text, complete_address text not null, latitude double precision not null, longitude double precision not null, location geography(Point,4326) generated always as (st_setsrid(st_makepoint(longitude,latitude),4326)::geography) stored, is_default boolean default false, created_at timestamptz default now());
create table public.service_areas (id uuid primary key default gen_random_uuid(), name text not null, boundary geography(Polygon,4326) not null, is_active boolean default true, created_at timestamptz default now());
create index service_areas_boundary_gix on public.service_areas using gist(boundary);
-- Placeholder rectangle around Chandigarh for initial development. Replace with the authoritative Chandigarh municipal boundary before production.
insert into public.service_areas(name,boundary) values ('Chandigarh', st_geogfromtext('POLYGON((76.68 30.65,76.90 30.65,76.90 30.80,76.68 30.80,76.68 30.65))')) on conflict do nothing;

create table public.wishlists (id uuid primary key default gen_random_uuid(), user_id uuid unique references profiles(id) on delete cascade not null);
create table public.wishlist_items (wishlist_id uuid references wishlists(id) on delete cascade, product_id uuid references products(id) on delete cascade, created_at timestamptz default now(), primary key(wishlist_id,product_id));
create table public.carts (id uuid primary key default gen_random_uuid(), user_id uuid unique references profiles(id) on delete cascade not null, updated_at timestamptz default now());
create table public.cart_items (cart_id uuid references carts(id) on delete cascade, product_id uuid references products(id), quantity int not null check(quantity>0), primary key(cart_id,product_id));
create table public.coupons (id uuid primary key default gen_random_uuid(), code text unique not null, discount_type text not null check(discount_type in ('percentage','fixed')), discount_value numeric(12,2) not null, minimum_order numeric(12,2) default 0, maximum_discount numeric(12,2), start_at timestamptz not null, expiry_at timestamptz not null, usage_limit int, per_user_limit int, is_active boolean default true);
create table public.coupon_usage (coupon_id uuid references coupons(id) on delete cascade, user_id uuid references profiles(id) on delete cascade, order_id uuid, used_at timestamptz default now());
create table public.delivery_settings (id boolean primary key default true, normal_charge numeric(12,2) default 20, fast_extra numeric(12,2) default 10, express_extra numeric(12,2) default 20, normal_minutes int default 180, fast_minutes int default 90, express_minutes int default 45, cod_enabled boolean default true, cod_minimum numeric(12,2) default 100);
insert into delivery_settings default values on conflict do nothing;
create table public.orders (id uuid primary key default gen_random_uuid(), order_number text unique not null, user_id uuid references profiles(id) not null, address_id uuid references addresses(id) not null, subtotal numeric(12,2) not null, discount numeric(12,2) default 0, coupon_discount numeric(12,2) default 0, delivery_charge numeric(12,2) default 0, total numeric(12,2) not null, delivery_type text not null, payment_method text not null, payment_status public.payment_status default 'pending', status public.order_status default 'pending', rider_id uuid references profiles(id), customer_otp_hash text, estimated_delivery_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
create table public.order_items (id uuid primary key default gen_random_uuid(), order_id uuid references orders(id) on delete cascade, product_id uuid references products(id), product_name_snapshot text not null, price_snapshot numeric(12,2) not null, quantity int not null, subtotal numeric(12,2) not null);
create table public.order_status_history (id uuid primary key default gen_random_uuid(), order_id uuid references orders(id) on delete cascade, actor_id uuid references profiles(id), previous_status public.order_status, new_status public.order_status not null, created_at timestamptz default now());
create table public.payments (id uuid primary key default gen_random_uuid(), order_id uuid references orders(id) on delete cascade, provider text, provider_payment_id text, amount numeric(12,2), status public.payment_status, created_at timestamptz default now());
create table public.delivery_partners (user_id uuid primary key references profiles(id) on delete cascade, rider_id text unique not null, state public.rider_state default 'pending', vehicle_type text default 'cycle', approved_at timestamptz, created_at timestamptz default now());
create table public.delivery_assignments (id uuid primary key default gen_random_uuid(), order_id uuid unique references orders(id) on delete cascade, rider_id uuid references profiles(id), accepted_at timestamptz, picked_up_at timestamptz, out_for_delivery_at timestamptz, delivered_at timestamptz, created_at timestamptz default now());
create table public.delivery_earnings (id uuid primary key default gen_random_uuid(), order_id uuid references orders(id), rider_id uuid references profiles(id), earning numeric(12,2) not null, created_at timestamptz default now());
create table public.notifications (id uuid primary key default gen_random_uuid(), user_id uuid references profiles(id) on delete cascade, title text not null, body text not null, read_at timestamptz, created_at timestamptz default now());
create table public.banners (id uuid primary key default gen_random_uuid(), image_url text not null, title text, subtitle text, button_text text, target_product_id uuid references products(id), target_category_id uuid references categories(id), is_active boolean default true, sort_order int default 0, start_at timestamptz, end_at timestamptz);
create table public.business_settings (id boolean primary key default true, business_name text default 'FMLY CRAFT', tagline text default 'Everything for Your Home Decor', logo_url text, support_phone text, support_whatsapp text, low_stock_threshold int default 5);
insert into business_settings default values on conflict do nothing;
create table public.support_settings (id boolean primary key default true, support_phone text, support_whatsapp text, faq_url text);
insert into support_settings default values on conflict do nothing;
create table public.audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references profiles(id), action text not null, table_name text, record_id uuid, metadata jsonb, created_at timestamptz default now());

alter table profiles enable row level security; alter table categories enable row level security; alter table subcategories enable row level security; alter table products enable row level security; alter table product_images enable row level security; alter table addresses enable row level security; alter table service_areas enable row level security; alter table wishlists enable row level security; alter table wishlist_items enable row level security; alter table carts enable row level security; alter table cart_items enable row level security; alter table orders enable row level security; alter table order_items enable row level security; alter table notifications enable row level security; alter table delivery_partners enable row level security; alter table delivery_assignments enable row level security; alter table delivery_earnings enable row level security;

create or replace function public.is_owner() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='owner'); $$;
create or replace function public.is_rider() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles p join delivery_partners d on d.user_id=p.id where p.id=auth.uid() and p.role='rider' and d.state='approved'); $$;

create policy "active products public" on products for select using (is_active=true or public.is_owner());
create policy "product images public" on product_images for select using (exists(select 1 from products p where p.id=product_images.product_id and (p.is_active=true or public.is_owner())));
create policy "categories public" on categories for select using (is_active=true or public.is_owner());
create policy "subcategories public" on subcategories for select using (is_active=true or public.is_owner());
create policy "owners products" on products for all using(public.is_owner()) with check(public.is_owner());
create policy "owners product images" on product_images for all using(public.is_owner()) with check(public.is_owner());
create policy "owners categories" on categories for all using(public.is_owner()) with check(public.is_owner());
create policy "owners subcategories" on subcategories for all using(public.is_owner()) with check(public.is_owner());
create policy "own profile" on profiles for select using(id=auth.uid() or public.is_owner());
create policy "own profile update" on profiles for update using(id=auth.uid());
create policy "own addresses" on addresses for all using(user_id=auth.uid() or public.is_owner()) with check(user_id=auth.uid() or public.is_owner());
create policy "own wishlist" on wishlists for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own wishlist items" on wishlist_items for all using(exists(select 1 from wishlists w where w.id=wishlist_items.wishlist_id and w.user_id=auth.uid())) with check(exists(select 1 from wishlists w where w.id=wishlist_items.wishlist_id and w.user_id=auth.uid()));
create policy "own carts" on carts for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own cart items" on cart_items for all using(exists(select 1 from carts c where c.id=cart_items.cart_id and c.user_id=auth.uid())) with check(exists(select 1 from carts c where c.id=cart_items.cart_id and c.user_id=auth.uid()));
create policy "own orders" on orders for select using(user_id=auth.uid() or public.is_owner() or (public.is_rider() and rider_id=auth.uid()));
create policy "own order items" on order_items for select using(exists(select 1 from orders o where o.id=order_items.order_id and (o.user_id=auth.uid() or public.is_owner() or (public.is_rider() and o.rider_id=auth.uid()))));
create policy "notifications own" on notifications for select using(user_id=auth.uid());
create policy "rider own" on delivery_partners for select using(user_id=auth.uid() or public.is_owner());
create policy "assignments rider" on delivery_assignments for select using(rider_id=auth.uid() or public.is_owner());
create policy "earnings rider" on delivery_earnings for select using(rider_id=auth.uid() or public.is_owner());
create policy "service area public" on service_areas for select using(is_active=true);

create or replace function public.validate_chandigarh_point(lat double precision, lng double precision) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from service_areas s where s.is_active and st_covers(s.boundary, st_setsrid(st_makepoint(lng,lat),4326)::geography)); $$;

create or replace function public.decrement_stock(p_product uuid,p_qty int) returns boolean language plpgsql security definer set search_path=public as $$ declare changed int; begin update products set stock_quantity=stock_quantity-p_qty,updated_at=now() where id=p_product and is_active and stock_quantity>=p_qty returning 1 into changed; return coalesce(changed,0)=1; end; $$;
