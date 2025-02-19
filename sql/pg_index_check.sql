WITH table_stats AS (
    SELECT 
        n.nspname AS schema_name,
        c.relname AS table_name,
        pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
        pg_relation_size(c.oid) AS table_size_bytes,
        COALESCE(s.seq_scan, 0) AS seq_scan_count,
        COALESCE(s.n_live_tup, 0) AS n_live_tup,
        COALESCE(s.n_dead_tup, 0) AS n_dead_tup,
        -- Calculate dead tuple ratio, ensuring no NULL values
        COALESCE(ROUND((s.n_dead_tup::numeric / NULLIF(s.n_live_tup + s.n_dead_tup, 0)) * 100, 2), 0) AS dead_tuple_ratio
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    LEFT JOIN pg_stat_user_tables s ON c.oid = s.relid  -- Use LEFT JOIN to avoid NULL values
    WHERE c.relkind = 'r'
),
table_stats_final AS (
    SELECT * ,
        -- Calculate dead tuple space, ensuring no NULL values
        COALESCE(ROUND((dead_tuple_ratio / 100.0) * table_size_bytes), 0) AS dead_tuple_size_estimate
    FROM table_stats
),
index_stats AS (
    SELECT 
        ui.schemaname AS schema_name,
        ui.relname AS table_name,
        ui.indexrelname AS index_name,
        pg_size_pretty(pg_relation_size(ui.indexrelid)) AS index_size,
        pg_relation_size(ui.indexrelid) AS index_size_bytes,
        COALESCE(ui.idx_scan, 0) AS index_usage_count,
        COALESCE(ui.idx_tup_read, 0) AS tuples_read,
        COALESCE(ui.idx_tup_fetch, 0) AS tuples_fetched
    FROM pg_stat_user_indexes ui
)
SELECT 
    t.schema_name,
    t.table_name,
    i.index_name,
    t.table_size,
    i.index_size,
    t.seq_scan_count,
    i.index_usage_count,
    t.dead_tuple_ratio,
    pg_size_pretty(t.dead_tuple_size_estimate) AS dead_tuple_size,
    -- Ensure index ratio and size comparison calculations do not result in NULL values
    COALESCE(ROUND((i.index_size_bytes::numeric / NULLIF(t.table_size_bytes, 0)) * 100, 2), 0) AS index_table_ratio,
    COALESCE(ROUND(((i.index_size_bytes - t.table_size_bytes)::numeric / NULLIF(NULLIF(t.table_size_bytes, 0), 1)) * 100, 2), 0) AS index_over_table_size
FROM table_stats_final t
JOIN index_stats i ON t.schema_name = i.schema_name AND t.table_name = i.table_name
-- WHERE i.index_usage_count < 100 -- Filter low usage indexes
ORDER BY 
    index_over_table_size DESC,   -- Index larger than table first
    t.seq_scan_count DESC,        -- Highest full table scan count first
    t.dead_tuple_ratio DESC,      -- Highest dead tuple ratio first
    index_table_ratio DESC,       -- Highest index size ratio first
    t.table_size_bytes DESC;      -- Largest table size first
