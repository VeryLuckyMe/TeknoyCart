-- ============================================================================
-- Student / Faculty ID format relaxation (v2)
-- ============================================================================
-- WHY
--   `student_id_migration.sql` enforced exactly `##-####-###`:
--       CHECK (student_id ~ '^[0-9]{2}-[0-9]{4}-[0-9]{3}$')
--   That silently blocks every faculty and other-grade-level ID of the shape
--   `2004-3732`, so those accounts could never complete registration.
--
-- WHAT
--   1. Drops the strict format constraint and replaces it with "6-12 digits,
--      dashes optional".
--   2. Makes uniqueness digit-based, so `2004-3732` and `20043732` count as the
--      same person.
--   3. Re-implements `is_student_id_available` with the same digit-based
--      comparison. The original definition is NOT in this repository, so review
--      the body below before running it.
--
-- BEFORE YOU RUN
--   * Take a backup / run on a staging project first.
--   * Step 2 fails if two existing rows already share the same digits
--     (e.g. `21-1029-315` and `211029315`). Find them with the query at the
--     bottom of this file.
--   * Run one statement at a time if you want to be able to stop half way.
-- ============================================================================

begin;

-- 1. Relax the format check -------------------------------------------------
alter table public.users drop constraint if exists check_student_id_format;

alter table public.users
  add constraint check_student_id_format
  check (
    student_id is null
    or (
      student_id ~ '^[0-9-]+$'
      and length(regexp_replace(student_id, '\D', '', 'g')) between 6 and 12
    )
  );

-- 2. Digit-based uniqueness -------------------------------------------------
alter table public.users drop constraint if exists unique_student_id;

create unique index if not exists users_student_id_digits_key
  on public.users ((regexp_replace(student_id, '\D', '', 'g')))
  where student_id is not null;

-- 3. Digit-based availability check ----------------------------------------
create or replace function public.is_student_id_available(p_student_id text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.users u
    where u.student_id is not null
      and regexp_replace(u.student_id, '\D', '', 'g')
        = regexp_replace(coalesce(p_student_id, ''), '\D', '', 'g')
  );
$$;

revoke all on function public.is_student_id_available(text) from public;
grant execute on function public.is_student_id_available(text)
  to anon, authenticated;

commit;

-- ---------------------------------------------------------------------------
-- Pre-flight: duplicates that would make step 2 fail
-- ---------------------------------------------------------------------------
-- select regexp_replace(student_id, '\D', '', 'g') as digits,
--        count(*), array_agg(user_id), array_agg(student_id)
-- from public.users
-- where student_id is not null
-- group by 1
-- having count(*) > 1;
--
-- Post-flight: the constraint must now accept both shapes
-- ---------------------------------------------------------------------------
-- select '21-1029-315' as id, '21-1029-315' ~ '^[0-9-]+$' as ok_format,
--        length(regexp_replace('21-1029-315', '\D', '', 'g')) as digits
-- union all
-- select '2004-3732', '2004-3732' ~ '^[0-9-]+$',
--        length(regexp_replace('2004-3732', '\D', '', 'g'));
