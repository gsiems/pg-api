-- Intended for running/troubleshooting individual test cases
SET client_min_messages = warning ;

CREATE SCHEMA IF NOT EXISTS tap ;

COMMENT ON SCHEMA tap IS 'Schema for pgTap objects' ;

CREATE EXTENSION IF NOT EXISTS pgtap SCHEMA tap ;

DROP SCHEMA IF EXISTS test CASCADE ;

CREATE SCHEMA IF NOT EXISTS test ;

\i 20_pre_tap.sql

SELECT plan ( 1 ) ;

--------------------------------------------------------------------------------
-- Load any test wrapper functions as needed
--\i some/path/to/test_wrapper_one.sql

--------------------------------------------------------------------------------
-- Insert the pgTap test to perform here:

SELECT ok (
    false,
    'this test will fail'
    ) ;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
\i 30_post_tap.sql
