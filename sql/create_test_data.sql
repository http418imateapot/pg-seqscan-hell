-- Check if schema exists, if not create it
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'bad_index_test') THEN
        EXECUTE 'CREATE SCHEMA bad_index_test';
    END IF;
END $$;

-- Switch to the new schema
SET search_path TO bad_index_test;

-- Create test table
CREATE TABLE test_orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT now(),
    amount DECIMAL(10, 2) NOT NULL,
    status TEXT CHECK (status IN ('pending', 'shipped', 'delivered', 'cancelled')),
    random_value TEXT
);

-- Insert fake data (200,000 rows to increase data volume)
INSERT INTO test_orders (user_id, order_date, amount, status, random_value)
SELECT 
    (random() * 1000)::INT, 
    now() - (random() * interval '365 days'),
    (random() * 1000)::DECIMAL(10,2),
    CASE WHEN random() < 0.1 THEN 'cancelled' 
         WHEN random() < 0.4 THEN 'shipped' 
         WHEN random() < 0.7 THEN 'delivered' 
         ELSE 'pending' END,
    md5(random()::TEXT)  -- Generate random value to simulate useless index
FROM generate_series(1, 200000);

-- Create indexes (some useful, some not)
CREATE INDEX idx_order_date ON test_orders (order_date);
CREATE INDEX idx_user_id ON test_orders (user_id);
CREATE INDEX idx_random ON test_orders (random_value); -- Possibly useless index
CREATE INDEX idx_status ON test_orders (status);      -- Possibly useless index
CREATE INDEX idx_amount ON test_orders (amount);      -- Over-indexing example

-- Delete some data to create dead tuples
DELETE FROM test_orders WHERE id % 5 = 0;

-- Generate dead tuples in PostgreSQL
UPDATE test_orders SET amount = amount * 1.1 WHERE id % 7 = 0;

-- Ensure vacuum does not remove dead tuples
ANALYZE test_orders;

-- Perform some queries to increase index miss/hint records
-- Query that uses index on order_date
SELECT * FROM test_orders WHERE order_date > now() - interval '30 days';

-- Query that uses index on user_id
SELECT * FROM test_orders WHERE user_id = 500;

-- Query that uses index on random_value (possibly useless)
SELECT * FROM test_orders WHERE random_value LIKE 'a%';

-- Query that uses index on status (possibly useless)
SELECT * FROM test_orders WHERE status = 'shipped';

-- Query that uses index on amount (over-indexing example)
SELECT * FROM test_orders WHERE amount > 500;

-- Query that does not use any index
SELECT * FROM test_orders WHERE amount < 100;

-- Additional queries to worsen index hint records
-- Query that uses index on random_value with a different pattern
SELECT * FROM test_orders WHERE random_value LIKE 'b%';

-- Query that uses index on status with a different value
SELECT * FROM test_orders WHERE status = 'pending';

-- Query that uses index on amount with a different range
SELECT * FROM test_orders WHERE amount BETWEEN 200 AND 300;

-- Query that uses index on user_id with a different value
SELECT * FROM test_orders WHERE user_id = 750;

-- Query that uses index on order_date with a different range
SELECT * FROM test_orders WHERE order_date BETWEEN now() - interval '60 days' AND now() - interval '30 days';
