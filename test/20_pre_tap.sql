
SET search_path = tap, plprofiler, plprofiler_client, pg_catalog, public ;

-- Turn off echo and keep things quiet.
\unset ECHO
\set QUIET 1

-- Format the output for nice TAP.
\pset format unaligned
\pset tuples_only true
\pset pager off

-- Revert all changes on failure.
\set ON_ERROR_ROLLBACK off
\set ON_ERROR_STOP on

BEGIN ;
