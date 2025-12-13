/**

### Util_meta


*/

SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = ON ;
SET check_function_bodies = TRUE ;
SET client_min_messages = warning ;
SET search_path = pg_catalog ;

\unset ON_ERROR_STOP

DROP SCHEMA IF EXISTS util_meta CASCADE ;

\set ON_ERROR_STOP

CREATE SCHEMA IF NOT EXISTS util_meta ;

COMMENT ON SCHEMA util_meta IS 'Database meta-data for objects (views, functions, procedures) for creating database API objects.' ;

-- Types -----------------------------------------------------------------------
\i util_meta/type/ut_parameters.sql
\i util_meta/type/ut_object.sql
\i util_meta/type/ut_parent_table.sql

-- Tables ----------------------------------------------------------------------
\i util_meta/table/st_default_param.sql
\i util_meta/table/rt_config_default.sql
\i util_meta/table/rt_plural_word.sql

-- Views -----------------------------------------------------------------------
\i util_meta/view/conftypes.sql
\i util_meta/view/contypes.sql
\i util_meta/view/prokinds.sql
\i util_meta/view/relkinds.sql
\i util_meta/view/typtypes.sql

\i util_meta/view/schemas.sql
\i util_meta/view/objects.sql
\i util_meta/view/columns.sql
\i util_meta/view/foreign_keys.sql
\i util_meta/view/object_grants.sql
\i util_meta/view/dependencies.sql
\i util_meta/view/extensions.sql

-- Functions -------------------------------------------------------------------

-- Common utility functions
\i util_meta/function/_to_plural.sql
\i util_meta/function/_to_singular.sql
\i util_meta/function/_base_name.sql
\i util_meta/function/_base_order.sql

\i util_meta/function/_resolve_parameter.sql

\i util_meta/function/_append_parameter.sql

\i util_meta/function/_cleanup_whitespace.sql
\i util_meta/function/_indent.sql
\i util_meta/function/_is_valid_object.sql
\i util_meta/function/_new_line.sql
\i util_meta/function/_table_noun.sql
\i util_meta/function/_proc_parameters.sql
\i util_meta/function/_calling_parameters.sql
\i util_meta/function/_boolean_casting.sql
\i util_meta/function/_find_func.sql
\i util_meta/function/_view_name.sql
\i util_meta/function/_find_view.sql

\i util_meta/function/_find_dt_parent.sql

-- Snippet functions
\i util_meta/function/_snip_declare_variables.sql
\i util_meta/function/_snip_documentation_block.sql

\i util_meta/function/_snip_log_params.sql
\i util_meta/function/_snip_object_comment.sql
\i util_meta/function/_snip_owners_and_grants.sql
\i util_meta/function/_snip_resolve_id.sql
\i util_meta/function/_snip_resolve_user_id.sql

\i util_meta/function/_snip_function_backmatter.sql
\i util_meta/function/_snip_function_frontmatter.sql
\i util_meta/function/_snip_procedure_backmatter.sql
\i util_meta/function/_snip_procedure_frontmatter.sql

\i util_meta/function/_snip_get_permissions.sql
\i util_meta/function/_snip_permissions_check.sql

--------------------------------------------------------------------------------
-- "Final" DDL generating functions for "regular API" objects
\i util_meta/function/mk_view.sql
\i util_meta/function/mk_user_type.sql
\i util_meta/function/mk_object_migration.sql

\i util_meta/function/mk_resolve_id_function.sql
\i util_meta/function/mk_can_do_function_shell.sql

\i util_meta/function/mk_find_function.sql
\i util_meta/function/mk_get_function.sql
\i util_meta/function/mk_list_function.sql
\i util_meta/function/mk_list_children_function.sql

\i util_meta/function/mk_priv_delete_procedure.sql
\i util_meta/function/mk_priv_insert_procedure.sql
\i util_meta/function/mk_priv_update_procedure.sql
\i util_meta/function/mk_priv_upsert_procedure.sql

\i util_meta/function/mk_api_procedure.sql

--------------------------------------------------------------------------------
-- JSON utility functions
\i util_meta/function/_json_identifier.sql

-- JSON snippet functions
\i util_meta/function/_snip_json_agg_build_object.sql
\i util_meta/function/_snip_json_build_object.sql

-- "Final" DDL generating functions for "JSON API" objects
\i util_meta/function/mk_json_view.sql
\i util_meta/function/mk_json_user_type.sql

\i util_meta/function/mk_json_function_wrapper.sql

--------------------------------------------------------------------------------
-- Testing functions
--\i util_meta/function/mk_test_procedure_wrapper.sql
