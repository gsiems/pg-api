/**
## Create the example_data schema

[201_create-example_data](201_create-example_data.sql)

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

CREATE SCHEMA IF NOT EXISTS example_data ;

COMMENT ON SCHEMA example_data IS 'TBD' ;

ALTER SCHEMA example_data OWNER TO example_db_owner ;
GRANT USAGE ON SCHEMA example_data TO example_db_owner ;
REVOKE USAGE ON SCHEMA example_data FROM public ;

-- Foreign Server --------------------------------------------------------------

-- Foreign Table ---------------------------------------------------------------

-- Sequences -------------------------------------------------------------------
\i example_data/sequence/seq_rt_id.sql

-- Functions -------------------------------------------------------------------

-- Tables ----------------------------------------------------------------------
\i example_data/table/st_app_role.sql
\i example_data/table/dt_user.sql
\i example_data/table/dt_user_app_role.sql
