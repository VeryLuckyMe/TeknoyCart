-- ============================================================
-- TeknoyCart: Role-Aware Email Policy Database Migration
-- Run this script in your Supabase Dashboard -> SQL Editor
-- ============================================================

-- 1. Drop old static CHECK constraint if it exists on public.users
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS check_institutional_email;

-- 2. Update Postgres trigger function to be role-aware
CREATE OR REPLACE FUNCTION verify_user_email_domain()
RETURNS TRIGGER AS $$
BEGIN
    -- Buyers must use an official @cit.edu institutional email
    IF NEW.role = 'BUYER' THEN
        IF NEW.email NOT LIKE '%@cit.edu' THEN
            RAISE EXCEPTION 'Registration restricted to official Cebu Institute of Technology - University (@cit.edu) institutional accounts.';
        END IF;
    END IF;
    
    -- Sellers and Admins can use any valid email address
    IF NEW.email NOT LIKE '%@%.%' THEN
        RAISE EXCEPTION 'Please enter a valid email address.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Re-attach trigger on public.users
DROP TRIGGER IF EXISTS trigger_users_email_domain_check ON public.users;
CREATE TRIGGER trigger_users_email_domain_check
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION verify_user_email_domain();
