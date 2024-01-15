
-- We could drop the test schema here, however that will cause the plprofiler,
-- when run, to gack
--DROP SCHEMA IF EXISTS test CASCADE ;

/* *****************************************************************************
Restore the mocked functions

*/

--DROP FUNCTION foo ;
--DROP FUNCTION bar ;

--ALTER FUNCTION foo_bak RENAME TO resolve_county_code ;
--ALTER FUNCTION bar_bak RENAME TO resolve_basin_code ;

/*
End of mock functions
*******************************************************************************/
