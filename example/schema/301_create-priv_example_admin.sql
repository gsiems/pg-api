/**
## Create the priv_example_admin schema

[301_create-priv_example_admin](301_create-priv_example_admin.sql)

*/

\connect example_db

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

CREATE SCHEMA IF NOT EXISTS priv_example_admin ;

COMMENT ON SCHEMA priv_example_admin IS 'TBD' ;

ALTER SCHEMA priv_example_admin OWNER TO example_db_owner ;
GRANT USAGE ON SCHEMA priv_example_admin TO example_db_owner ;
REVOKE USAGE ON SCHEMA priv_example_admin FROM public ;

-- Types -----------------------------------------------------------------------

-- Views and Materialized Views ------------------------------------------------
\i priv_example_admin/view/sv_app_role.sql
\i priv_example_admin/view/dv_user.sql
\i priv_example_admin/view/dv_user_app_role.sql

-- Functions -------------------------------------------------------------------
\i priv_example_admin/function/resolve_user_id.sql

-- Procedures ------------------------------------------------------------------
\i priv_example_admin/procedure/priv_set_user_app_roles.sql
\i priv_example_admin/procedure/priv_insert_user.sql
\i priv_example_admin/procedure/priv_update_user.sql
\i priv_example_admin/procedure/priv_upsert_user.sql
