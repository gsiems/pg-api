/**
## Create the example_admin schema

[302_create-example_admin](302_create-example_admin.sql)

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

CREATE SCHEMA IF NOT EXISTS example_admin ;

COMMENT ON SCHEMA example_admin IS 'TBD' ;

ALTER SCHEMA example_admin OWNER TO example_db_owner ;
GRANT USAGE ON SCHEMA example_admin TO example_db_owner ;
REVOKE USAGE ON SCHEMA example_admin FROM public ;

-- Types -----------------------------------------------------------------------

-- Views and Materialized Views ------------------------------------------------

-- Functions -------------------------------------------------------------------
\i example_admin/function/can_do.sql
\i example_admin/function/find_users.sql
\i example_admin/function/get_user.sql
\i example_admin/function/list_users.sql

-- Procedures ------------------------------------------------------------------
\i example_admin/procedure/insert_user.sql
\i example_admin/procedure/update_user.sql
\i example_admin/procedure/upsert_user.sql
