-- Switch to the new schema
SET search_path TO bad_index_test;

-- Drop indexes
DROP INDEX IF EXISTS idx_order_date;
DROP INDEX IF EXISTS idx_user_id;
DROP INDEX IF EXISTS idx_random;
DROP INDEX IF EXISTS idx_useless;
DROP INDEX IF EXISTS idx_status;
DROP INDEX IF EXISTS idx_amount;

-- Drop table
DROP TABLE IF EXISTS test_orders;

-- Drop schema
DROP SCHEMA IF EXISTS bad_index_test CASCADE;
