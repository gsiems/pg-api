
SET client_min_messages = warning ;

CREATE SCHEMA IF NOT EXISTS tap ;

COMMENT ON SCHEMA tap IS 'Schema for pgTap objects' ;

CREATE EXTENSION IF NOT EXISTS pgtap SCHEMA tap ;

DROP SCHEMA IF EXISTS test CASCADE ;

CREATE SCHEMA IF NOT EXISTS test ;

/* *****************************************************************************
Mock functions

For some functions/procedures it may be necessary to replace the actual
functions or procedures with a mock version so that the tests that depended on
them could run to completion.

Note that we should restore the actual functions/procedures when we are
finished (via 40_finialize_testrun.sql).

*/
--ALTER FUNCTION foo RENAME TO foo_bak ;
--ALTER FUNCTION bar RENAME TO bar_bak ;

--\i some/path/to/foo.sql
--\i some/path/to/bar.sql

/*
End of mock functions
*******************************************************************************/

/* *****************************************************************************
Test wrapper functions

While we could, and at one time did, create the test wrapper functions as part
of each test file (such that the functions were also rolled back when the test
finished) this doesn't play well with plprofiler as it fails if a function that
it was profiling is dropped before the data can be saved.

By placing the test wrapper function creation here they get persisted to the
database so that they don't cause a plprofiler failure.

*/

--\i some/path/to/test_wrapper_one.sql
--\i some/path/to/test_wrapper_two.sql

/*
End of test wrapper functions
*******************************************************************************/
