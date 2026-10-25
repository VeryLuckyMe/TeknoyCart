-- Atomic, server-priced cart checkout and least-privilege write access.
-- Apply after the existing order columns/status migrations.

CREATE OR REPLACE FUNCTION public.place_orders_atomic(
  p_lines jsonb,
  p_payment_method text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_buyer uuid := auth.uid();
  v_line jsonb;
  v_idx bigint;
  v_product_id uuid;
  v_variant_id uuid;
  v_quantity integer;
  v_unit_price numeric;
  v_total numeric;
  v_seller uuid;
  v_preorder_enabled boolean;
  v_product_status text;
  v_stock integer;
  v_reserved integer;
  v_is_preorder boolean;
  v_inquiry uuid;
  v_order uuid;
  v_orders jsonb := '[]'::jsonb;
  v_lines_count integer;
BEGIN
  IF v_buyer IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;
  IF jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) NOT BETWEEN 1 AND 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_LINES');
  END IF;
  IF p_payment_method NOT IN ('GCASH', 'CASH_ON_PICKUP') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_PAYMENT_METHOD');
  END IF;

  -- Stable lock order avoids deadlocks when two buyers check out overlapping carts.
  FOR v_line, v_idx IN
    SELECT line, ordinality
    FROM jsonb_array_elements(p_lines) WITH ORDINALITY AS x(line, ordinality)
    ORDER BY (line->>'variant_id')
  LOOP
    v_product_id := (v_line->>'product_id')::uuid;
    v_variant_id := (v_line->>'variant_id')::uuid;
    v_quantity := (v_line->>'quantity')::integer;
    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'INVALID_QUANTITY';
    END IF;

    SELECT p.seller_id, p.status::text, p.is_preorder_enabled,
           p.base_price + pv.additional_price, inv.stock_qty, inv.reserved_qty
      INTO v_seller, v_product_status, v_preorder_enabled,
           v_unit_price, v_stock, v_reserved
      FROM public.products p
      JOIN public.product_variants pv ON pv.product_id = p.product_id
      JOIN public.inventory inv ON inv.variant_id = pv.variant_id
      JOIN public.users u ON u.user_id = p.seller_id
     WHERE p.product_id = v_product_id
       AND pv.variant_id = v_variant_id
       AND u.role = 'SELLER'
       AND u.is_seller_verified IS TRUE
     FOR UPDATE OF inv;
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_LISTING'; END IF;
    IF v_product_status <> 'ACTIVE' THEN RAISE EXCEPTION 'PRODUCT_NOT_ACTIVE'; END IF;
    IF v_seller = v_buyer THEN RAISE EXCEPTION 'CANNOT_PURCHASE_OWN_PRODUCT'; END IF;
    IF (v_line->>'is_preorder')::boolean IS TRUE AND v_preorder_enabled IS NOT TRUE THEN
      RAISE EXCEPTION 'PREORDER_NOT_ALLOWED';
    END IF;

    -- Never accept a price from the app. Current listing and variant determine it.
    IF (v_line->>'unit_price')::numeric IS DISTINCT FROM v_unit_price THEN
      RAISE EXCEPTION 'PRICE_MISMATCH';
    END IF;
    v_total := round(v_unit_price * v_quantity, 2);
    v_is_preorder := FALSE;
    IF v_stock - v_reserved >= v_quantity AND (v_line->>'is_preorder')::boolean IS NOT TRUE THEN
      UPDATE public.inventory
         SET reserved_qty = reserved_qty + v_quantity, last_updated = now()
       WHERE variant_id = v_variant_id;
    ELSIF v_preorder_enabled IS TRUE THEN
      v_is_preorder := TRUE;
    ELSE
      RAISE EXCEPTION 'INSUFFICIENT_STOCK';
    END IF;

    INSERT INTO public.inquiries (buyer_id, product_id, variant_id, quantity, inquiry_type, message)
    VALUES (v_buyer, v_product_id, v_variant_id, v_quantity, 'AVAILABILITY', 'Checkout order')
    RETURNING inquiry_id INTO v_inquiry;

    INSERT INTO public.orders (
      inquiry_id, buyer_id, seller_id, variant_id, quantity, unit_price, total_amount,
      payment_method, status, version, pickup_location, pickup_day, pickup_time,
      is_preorder, reservation_expires_at
    ) VALUES (
      v_inquiry, v_buyer, v_seller, v_variant_id, v_quantity, v_unit_price, v_total,
      p_payment_method::public.payment_method, 'PLACED', 0,
      v_line->>'pickup_location', v_line->>'pickup_day', v_line->>'pickup_time',
      v_is_preorder, CASE WHEN v_is_preorder THEN NULL ELSE now() + interval '24 hours' END
    ) RETURNING order_id INTO v_order;

    v_orders := v_orders || jsonb_build_array(jsonb_build_object(
      'line_index', v_idx - 1, 'order_id', v_order, 'total_amount', v_total
    ));
  END LOOP;

  SELECT count(*) INTO v_lines_count FROM jsonb_array_elements(p_lines);
  IF jsonb_array_length(v_orders) <> v_lines_count THEN RAISE EXCEPTION 'CHECKOUT_INCOMPLETE'; END IF;
  RETURN jsonb_build_object('success', true, 'orders', v_orders);
EXCEPTION
  WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM IN ('INVALID_QUANTITY', 'INVALID_LISTING', 'PRODUCT_NOT_ACTIVE',
                   'CANNOT_PURCHASE_OWN_PRODUCT', 'PREORDER_NOT_ALLOWED',
                   'INSUFFICIENT_STOCK', 'PRICE_MISMATCH') THEN
      RETURN jsonb_build_object('success', false, 'error', SQLERRM);
    END IF;
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.place_orders_atomic(jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_orders_atomic(jsonb, text) TO authenticated;
-- Prevent clients from continuing to use the earlier client-priced single-line RPC.
DO $$
BEGIN
  IF to_regprocedure('public.place_order_atomic(uuid,integer,boolean,uuid,uuid,numeric,numeric,text,text,text,text,boolean)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.place_order_atomic(uuid,integer,boolean,uuid,uuid,numeric,numeric,text,text,text,text,boolean) FROM PUBLIC, authenticated';
  END IF;
END;
$$;

-- RLS policies cannot limit changed columns. Revoke broad row updates and
-- grant only seller scheduling columns; state and money remain server-owned.
REVOKE UPDATE, DELETE ON public.orders FROM authenticated;
GRANT UPDATE (pickup_location, pickup_day, pickup_time) ON public.orders TO authenticated;
DROP POLICY IF EXISTS orders_update_buyer_payment ON public.orders;
DROP POLICY IF EXISTS orders_update_seller_logistics ON public.orders;
DROP POLICY IF EXISTS "orders_update_buyer_payment" ON public.orders;
DROP POLICY IF EXISTS "orders_update_seller_logistics" ON public.orders;
CREATE POLICY orders_update_seller_logistics ON public.orders
  FOR UPDATE TO authenticated
  USING (auth.uid() = seller_id
         AND EXISTS (SELECT 1 FROM public.users u WHERE u.user_id = auth.uid() AND u.role = 'SELLER' AND u.is_seller_verified IS TRUE)
         AND status NOT IN ('COMPLETED', 'CANCELLED', 'REJECTED', 'RETURN_COMPLETED')
         AND coalesce(seller_handed_off, false) = false)
  WITH CHECK (auth.uid() = seller_id
              AND EXISTS (SELECT 1 FROM public.users u WHERE u.user_id = auth.uid() AND u.role = 'SELLER' AND u.is_seller_verified IS TRUE)
              AND status NOT IN ('COMPLETED', 'CANCELLED', 'REJECTED', 'RETURN_COMPLETED')
              AND coalesce(seller_handed_off, false) = false);

ALTER TABLE public.order_returns ENABLE ROW LEVEL SECURITY;
-- Older live databases may predate this field in the returns table.
ALTER TABLE public.order_returns
  ADD COLUMN IF NOT EXISTS seller_response_note TEXT,
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;
REVOKE UPDATE, DELETE ON public.order_returns FROM authenticated;
GRANT UPDATE (status, seller_response_note, resolved_at) ON public.order_returns TO authenticated;
DROP POLICY IF EXISTS order_returns_select_parties ON public.order_returns;
DROP POLICY IF EXISTS order_returns_insert_buyer ON public.order_returns;
DROP POLICY IF EXISTS order_returns_update_seller ON public.order_returns;
DROP POLICY IF EXISTS "order_returns_select_parties" ON public.order_returns;
DROP POLICY IF EXISTS "order_returns_insert_buyer" ON public.order_returns;
DROP POLICY IF EXISTS "order_returns_update_seller" ON public.order_returns;
CREATE POLICY order_returns_select_parties ON public.order_returns
  FOR SELECT TO authenticated USING (
    auth.uid() = requested_by OR EXISTS (
      SELECT 1 FROM public.orders o JOIN public.users u ON u.user_id = o.seller_id
       WHERE o.order_id = order_returns.order_id AND o.seller_id = auth.uid()
         AND u.role = 'SELLER' AND u.is_seller_verified IS TRUE
    ));
CREATE POLICY order_returns_insert_buyer ON public.order_returns
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = requested_by AND status = 'PENDING'
    AND seller_response_note IS NULL AND resolved_at IS NULL
    AND EXISTS (
      SELECT 1 FROM public.orders o WHERE o.order_id = order_returns.order_id
        AND o.buyer_id = auth.uid() AND o.status = 'COMPLETED'
    ));
CREATE POLICY order_returns_update_seller ON public.order_returns
  FOR UPDATE TO authenticated USING (
    status = 'PENDING' AND EXISTS (
      SELECT 1 FROM public.orders o JOIN public.users u ON u.user_id = o.seller_id
       WHERE o.order_id = order_returns.order_id AND o.seller_id = auth.uid()
         AND u.role = 'SELLER' AND u.is_seller_verified IS TRUE
    )) WITH CHECK (
      status IN ('APPROVED', 'DECLINED') AND EXISTS (
        SELECT 1 FROM public.orders o JOIN public.users u ON u.user_id = o.seller_id
         WHERE o.order_id = order_returns.order_id AND o.seller_id = auth.uid()
           AND u.role = 'SELLER' AND u.is_seller_verified IS TRUE
      ));
