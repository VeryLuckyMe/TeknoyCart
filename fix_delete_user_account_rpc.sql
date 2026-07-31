-- =============================================================
-- TeknoyCart Fix: Explicit Public Schema User Account Deletion RPC
-- Execute this SQL script in Supabase SQL Editor
-- =============================================================

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void AS $$
DECLARE
    uid UUID := auth.uid();
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Safely delete dependent records in explicit dependency order without failing if optional tables don't exist
    BEGIN DELETE FROM public.order_returns WHERE requested_by = uid; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.order_items WHERE order_id IN (SELECT order_id FROM public.orders WHERE buyer_id = uid OR seller_id = uid); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.orders WHERE buyer_id = uid OR seller_id = uid; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.messages WHERE sender_id = uid; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.chat_rooms WHERE buyer_id = uid OR seller_id = uid; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.product_variants WHERE product_id IN (SELECT id FROM public.products WHERE seller_id = uid); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.products WHERE seller_id = uid; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.store_profiles WHERE owner_id = uid; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DELETE FROM public.users WHERE user_id = uid; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Permanently delete the Auth user record
    DELETE FROM auth.users WHERE id = uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permissions explicitly to authenticated & anon roles
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated, anon, service_role;

-- Force Supabase PostgREST API engine to reload schema cache immediately
NOTIFY pgrst, 'reload schema';
