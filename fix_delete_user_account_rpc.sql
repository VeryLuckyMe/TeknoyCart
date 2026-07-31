-- =============================================================
-- TeknoyCart Fix: Secure Cascade User Account Deletion RPC
-- Execute this SQL script in Supabase SQL Editor
-- =============================================================

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void AS $$
DECLARE
    uid UUID := auth.uid();
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Safely delete dependent records in explicit dependency order to prevent 409 Foreign Key conflict
    DELETE FROM public.order_returns WHERE requested_by = uid;
    DELETE FROM public.order_items WHERE order_id IN (SELECT order_id FROM public.orders WHERE buyer_id = uid OR seller_id = uid);
    DELETE FROM public.orders WHERE buyer_id = uid OR seller_id = uid;
    DELETE FROM public.messages WHERE sender_id = uid;
    DELETE FROM public.chat_rooms WHERE buyer_id = uid OR seller_id = uid;
    DELETE FROM public.product_variants WHERE product_id IN (SELECT id FROM public.products WHERE seller_id = uid);
    DELETE FROM public.products WHERE seller_id = uid;
    DELETE FROM public.store_profiles WHERE owner_id = uid;
    DELETE FROM public.users WHERE user_id = uid;

    -- Permanently delete the Auth user record
    DELETE FROM auth.users WHERE id = uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;
