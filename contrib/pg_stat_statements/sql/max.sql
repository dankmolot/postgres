--
-- Test deallocation of entries
--

SHOW pg_stat_statements.max;

SET pg_stat_statements.track = 'all';

-- Create 101 tables.
DO $$
BEGIN
  FOR i IN 1..101 LOOP
    EXECUTE format('create table t%s (a int)', lpad(i::text, 3, '0'));
  END LOOP;
END
$$;

SELECT pg_stat_statements_reset() IS NOT NULL AS t;

-- Run 98 queries.
DO $$
BEGIN
  FOR i IN 1..98 LOOP
    EXECUTE format('select * from t%s', lpad(i::text, 3, '0'));
  END LOOP;
END
$$;

-- All 98 queries should be registered.  We just check the first and
-- last to keep the output small.
SELECT query FROM pg_stat_statements WHERE query LIKE '%t001%' OR query LIKE '%t098%' ORDER BY query;

-- Query tables 2 through 98 again, so they have a higher calls count.
-- Table 1 still has previous calls count.
DO $$
BEGIN
  FOR i IN 2..98 LOOP
    EXECUTE format('select * from t%s', lpad(i::text, 3, '0'));
  END LOOP;
END
$$;

-- Run 3 more queries.  This will exceed the max and will cause the
-- least used query to be deallocated.  (The queries for
-- pg_stat_statements themselves will also register, so fewer than 3
-- queries will also cause overflow, but let's keep this scenario
-- self-contained.)
DO $$
BEGIN
  FOR i IN 99..101 LOOP
    EXECUTE format('select * from t%s', lpad(i::text, 3, '0'));
  END LOOP;
END
$$;

-- Check that the limit was kept.
SELECT count(*) <= 100 FROM pg_stat_statements;
-- Check that record for t001 has been deallocated.
SELECT query FROM pg_stat_statements WHERE query LIKE '%t001%' ORDER BY query;
-- Check deallocation count.
SELECT dealloc > 0 AS t FROM pg_stat_statements_info;
