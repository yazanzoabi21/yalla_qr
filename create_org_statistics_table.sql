-- =====================================================
-- Create function to calculate and update statistics
-- This function queries your data and updates org_statistics table
-- =====================================================
create or replace function public.update_org_statistics(p_account_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_stats record;
begin
  -- Calculate all statistics
  select
    -- QR Codes
    (select count(*) from public.qr_codes where account_id = p_account_id) as total_qr_codes,
    
    -- Scans (join through qr_codes since scan_logs doesn't have account_id)
    (select count(*) from public.scan_logs sl
     inner join public.qr_codes qr on sl.qr_code_id = qr.id
     where qr.account_id = p_account_id) as total_scans,
    (select count(*) from public.scan_logs sl
     inner join public.qr_codes qr on sl.qr_code_id = qr.id
     where qr.account_id = p_account_id 
     and sl.scanned_at >= current_date) as scans_today,
    (select count(*) from public.scan_logs sl
     inner join public.qr_codes qr on sl.qr_code_id = qr.id
     where qr.account_id = p_account_id 
     and sl.scanned_at >= date_trunc('week', current_date)) as scans_this_week,
    (select count(*) from public.scan_logs sl
     inner join public.qr_codes qr on sl.qr_code_id = qr.id
     where qr.account_id = p_account_id 
     and sl.scanned_at >= date_trunc('month', current_date)) as scans_this_month,
    
    -- Visitors (use user_id and org_id, not visitor_id and account_id)
    (select count(distinct user_id) from public.organization_visitors where org_id = p_account_id) as unique_visitors,
    
    -- Products
    (select count(*) from public.products where account_id = p_account_id) as total_products,
    (select count(*) from public.products where account_id = p_account_id and quantity > 0) as products_in_stock,
    (select count(*) from public.products where account_id = p_account_id and quantity = 0) as products_out_of_stock,
    
    -- Orders
    (select count(*) from public.orders where account_id = p_account_id) as total_orders,
    (select count(*) from public.orders where account_id = p_account_id and status = 'pending') as pending_orders,
    (select count(*) from public.orders where account_id = p_account_id and status = 'completed') as completed_orders,
    (select count(*) from public.orders where account_id = p_account_id and status = 'cancelled') as cancelled_orders,
    (select count(*) from public.orders 
     where account_id = p_account_id 
     and created_at >= current_date) as orders_today,
    (select count(*) from public.orders 
     where account_id = p_account_id 
     and created_at >= date_trunc('week', current_date)) as orders_this_week,
    (select count(*) from public.orders 
     where account_id = p_account_id 
     and created_at >= date_trunc('month', current_date)) as orders_this_month,
    
    -- Revenue (only total_amount exists in orders table, USD is optional/not in DB)
    (select coalesce(sum(total_amount), 0) from public.orders 
     where account_id = p_account_id and status = 'completed') as total_revenue_lbp,
    0 as total_revenue_usd, -- USD not stored in orders table
    
    -- Deliveries (join through order_delivery_assignments table)
    (select count(*) from public.delivery_status ds
     inner join public.order_delivery_assignments oda on ds.assignment_id = oda.id
     inner join public.orders o on oda.order_id = o.id
     where o.account_id = p_account_id) as total_deliveries,
    (select count(*) from public.delivery_status ds
     inner join public.order_delivery_assignments oda on ds.assignment_id = oda.id
     inner join public.orders o on oda.order_id = o.id
     where o.account_id = p_account_id and ds.status in ('pending', 'accepted', 'enRoute', 'arriving', 'arrived')) as active_deliveries,
    (select count(*) from public.delivery_status ds
     inner join public.order_delivery_assignments oda on ds.assignment_id = oda.id
     inner join public.orders o on oda.order_id = o.id
     where o.account_id = p_account_id and ds.status = 'completed') as completed_deliveries
  into v_stats;

  -- Insert or update statistics
  insert into public.org_statistics (
    account_id,
    total_qr_codes,
    total_scans,
    scans_today,
    scans_this_week,
    scans_this_month,
    unique_visitors,
    total_products,
    products_in_stock,
    products_out_of_stock,
    total_orders,
    pending_orders,
    completed_orders,
    cancelled_orders,
    orders_today,
    orders_this_week,
    orders_this_month,
    total_revenue_lbp,
    total_revenue_usd,
    total_deliveries,
    active_deliveries,
    completed_deliveries,
    last_updated_at
  ) values (
    p_account_id,
    v_stats.total_qr_codes,
    v_stats.total_scans,
    v_stats.scans_today,
    v_stats.scans_this_week,
    v_stats.scans_this_month,
    v_stats.unique_visitors,
    v_stats.total_products,
    v_stats.products_in_stock,
    v_stats.products_out_of_stock,
    v_stats.total_orders,
    v_stats.pending_orders,
    v_stats.completed_orders,
    v_stats.cancelled_orders,
    v_stats.orders_today,
    v_stats.orders_this_week,
    v_stats.orders_this_month,
    v_stats.total_revenue_lbp,
    v_stats.total_revenue_usd,
    v_stats.total_deliveries,
    v_stats.active_deliveries,
    v_stats.completed_deliveries,
    timezone('utc', now())
  )
  on conflict (account_id)
  do update set
    total_qr_codes = excluded.total_qr_codes,
    total_scans = excluded.total_scans,
    scans_today = excluded.scans_today,
    scans_this_week = excluded.scans_this_week,
    scans_this_month = excluded.scans_this_month,
    unique_visitors = excluded.unique_visitors,
    total_products = excluded.total_products,
    products_in_stock = excluded.products_in_stock,
    products_out_of_stock = excluded.products_out_of_stock,
    total_orders = excluded.total_orders,
    pending_orders = excluded.pending_orders,
    completed_orders = excluded.completed_orders,
    cancelled_orders = excluded.cancelled_orders,
    orders_today = excluded.orders_today,
    orders_this_week = excluded.orders_this_week,
    orders_this_month = excluded.orders_this_month,
    total_revenue_lbp = excluded.total_revenue_lbp,
    total_revenue_usd = excluded.total_revenue_usd,
    total_deliveries = excluded.total_deliveries,
    active_deliveries = excluded.active_deliveries,
    completed_deliveries = excluded.completed_deliveries,
    last_updated_at = timezone('utc', now());
end;
$$;

-- =====================================================
-- Why run this in Supabase?
-- =====================================================
-- This creates a SERVER-SIDE function that:
-- 1. Counts QR codes, scans, products, orders, etc. from your database
-- 2. Calculates revenue, deliveries, and time-based metrics
-- 3. Updates the org_statistics table with calculated values
--
-- The Flutter app calls this function via:
--   await _supabase.rpc('update_org_statistics', params: {'p_account_id': accountId});
--
-- Without this function, your statistics screen will show empty data!
-- =====================================================

-- =====================================================
-- OPTIONAL: Test the function
-- =====================================================
-- Run this to update stats for all accounts:
-- SELECT update_org_statistics(account_id) FROM org_statistics;

-- Or test with one specific account:
-- SELECT update_org_statistics('3599697d-a194-437d-b759-92385e82e02');
-- Then check the table: SELECT * FROM org_statistics;
