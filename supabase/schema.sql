-- EquestrianConnect schema. Paste into Supabase SQL Editor.
-- Idempotent: safe to re-run.

-- =========================================================================
-- Tables
-- =========================================================================

create table if not exists public.profiles (
    id            uuid primary key references auth.users(id) on delete cascade,
    email         text,
    full_name     text,
    user_type     text,
    profile_image text,
    created_date  timestamptz not null default now()
);

create table if not exists public.horses (
    id                  uuid primary key default gen_random_uuid(),
    name                text not null,
    barn_name           text,
    breed               text,
    color               text,
    date_of_birth       text,
    gender              text,
    registration_number text,
    discipline          text,
    owner_id            text,
    trainer_id          text,
    profile_image       text,
    total_earnings      numeric,
    created_date        timestamptz not null default now()
);
create index if not exists horses_owner_idx   on public.horses(owner_id);
create index if not exists horses_trainer_idx on public.horses(trainer_id);

create table if not exists public.calendar_events (
    id                    uuid primary key default gen_random_uuid(),
    title                 text not null,
    type                  text not null,
    start_date            text not null,
    end_date              text,
    all_day               boolean,
    location              text,
    description           text,
    horse_ids             text[],
    user_id               text,
    is_recurring          boolean,
    recurrence_frequency  text,
    recurrence_count      int,
    recurrence_parent_id  text,
    created_date          timestamptz not null default now()
);
create index if not exists calendar_events_user_idx  on public.calendar_events(user_id);
create index if not exists calendar_events_start_idx on public.calendar_events(start_date);

create table if not exists public.training_logs (
    id           uuid primary key default gen_random_uuid(),
    horse_id     text not null,
    date         text not null,
    user_id      text,
    created_date timestamptz not null default now()
);
create index if not exists training_logs_horse_idx on public.training_logs(horse_id);
create index if not exists training_logs_user_idx  on public.training_logs(user_id);

create table if not exists public.conversations (
    id                 uuid primary key default gen_random_uuid(),
    participants       text[] not null,
    horse_id           text,
    last_message       text,
    last_message_date  text,
    unread_count       int,
    created_date       timestamptz not null default now()
);

create table if not exists public.messages (
    id              uuid primary key default gen_random_uuid(),
    conversation_id text not null,
    sender_id       text not null,
    recipient_id    text,
    content         text,
    video_url       text,
    horse_id        text,
    created_date    timestamptz not null default now()
);
create index if not exists messages_conv_idx on public.messages(conversation_id);

create table if not exists public.posts (
    id            uuid primary key default gen_random_uuid(),
    author_id     text,
    author_name   text,
    caption       text,
    media_type    text,
    media_url     text,
    horse_id      text,
    horse_name    text,
    tags          text[],
    for_sale      boolean,
    price         numeric,
    location      text,
    created_date  timestamptz not null default now(),
    like_count    int,
    comment_count int
);
create index if not exists posts_author_idx on public.posts(author_id);

create table if not exists public.likes (
    id           uuid primary key default gen_random_uuid(),
    post_id      text not null,
    user_id      text,
    created_date timestamptz not null default now()
);
create index if not exists likes_post_idx on public.likes(post_id);

create table if not exists public.marketplace_listings (
    id                uuid primary key default gen_random_uuid(),
    title             text not null,
    type              text not null,
    price             numeric,
    price_negotiable  boolean,
    description       text,
    images            text[],
    videos            text[],
    location          text,
    seller_id         text,
    seller_name       text,
    seller_phone      text,
    status            text,
    breed             text,
    age               int,
    gender            text,
    discipline        text,
    height            text,
    featured          boolean,
    created_date      timestamptz not null default now()
);
create index if not exists marketplace_seller_idx on public.marketplace_listings(seller_id);

create table if not exists public.horse_documents (
    id           uuid primary key default gen_random_uuid(),
    horse_id     text not null,
    title        text not null,
    type         text not null,
    date         text,
    notes        text,
    file_url     text,
    file_name    text,
    image_data   text,
    uploaded_by  text,
    created_date timestamptz not null default now()
);
create index if not exists horse_documents_horse_idx on public.horse_documents(horse_id);

-- =========================================================================
-- Auto-create profile on new auth user (belt-and-suspenders with client-side
-- fallback in AuthManager.verifyOTP).
-- =========================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email)
    values (new.id, new.email)
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- =========================================================================
-- Row-level security. Pragmatic first pass: authenticated users can do
-- anything; anon users blocked. Tighten per-table before public launch.
-- =========================================================================

do $$
declare
    t text;
begin
    for t in
        select tablename from pg_tables
        where schemaname = 'public'
          and tablename in (
            'profiles','horses','calendar_events','training_logs',
            'conversations','messages','posts','likes',
            'marketplace_listings','horse_documents'
          )
    loop
        execute format('alter table public.%I enable row level security', t);
        execute format('drop policy if exists authed_all on public.%I', t);
        execute format(
            'create policy authed_all on public.%I for all to authenticated using (true) with check (true)',
            t
        );
    end loop;
end $$;

-- =========================================================================
-- Storage bucket for image/file uploads.
-- =========================================================================

insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do update set public = true;

drop policy if exists "uploads authed write" on storage.objects;
create policy "uploads authed write" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'uploads');

drop policy if exists "uploads public read" on storage.objects;
create policy "uploads public read" on storage.objects
    for select to anon, authenticated
    using (bucket_id = 'uploads');
