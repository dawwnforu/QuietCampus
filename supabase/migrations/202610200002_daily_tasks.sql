-- Shared editorial tasks only; personal answers/completion stay in encrypted records.
create table public.daily_tasks (
  task_date date primary key,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  instructions text not null check (char_length(btrim(instructions)) between 1 and 4000),
  estimated_minutes smallint check (estimated_minutes > 0),
  published boolean not null default false
);

alter table public.daily_tasks enable row level security;
revoke all on public.daily_tasks from public, anon, authenticated;
grant select on public.daily_tasks to authenticated;
create policy published_daily_tasks on public.daily_tasks for select to authenticated
using (published and (select public.account_active()));
