
SET statement_timeout = 0 ;
SET client_encoding = 'UTF8' ;
SET standard_conforming_strings = on ;
SET check_function_bodies = true ;
SET client_min_messages = warning ;

\unset ON_ERROR_STOP

DROP SCHEMA IF EXISTS util_meta CASCADE ;
DROP ROLE IF EXISTS util_meta_read ;
DROP ROLE IF EXISTS util_meta_owner ;

CREATE ROLE util_meta_owner ;

CREATE ROLE util_meta_read ;

\set ON_ERROR_STOP

ALTER USER util_meta_owner NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE util_meta_owner IS 'Ownership role for util_meta functions and data' ;

ALTER ROLE util_meta_read NOLOGIN
    NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION ;

COMMENT ON ROLE util_meta_read IS 'Read-only role for accessing util_meta functions and data' ;

CREATE SCHEMA IF NOT EXISTS util_meta ;

COMMENT ON SCHEMA util_meta IS 'Database meta-data for objects (views, functions, procedures) for creating database API objects.' ;

ALTER SCHEMA util_meta OWNER TO util_meta_owner ;

DO $$
    BEGIN
        EXECUTE format ( 'GRANT TEMPORARY ON DATABASE %I TO util_meta_owner', current_database()::text );

        EXECUTE format ( 'GRANT util_meta_read TO %s ;', current_user::text );

    END
$$;

-- Types -----------------------------------------------------------------------
\i util_meta/type/ut_parameters.sql
\i util_meta/type/ut_proc.sql

-- Tables ----------------------------------------------------------------------
\i util_meta/table/st_default_param.sql
\i util_meta/table/rt_config_default.sql

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
\i util_meta/function/resolve_parameter.sql

\i util_meta/function/append_parameter.sql

\i util_meta/function/cleanup_whitespace.sql
\i util_meta/function/indent.sql
\i util_meta/function/is_valid_object.sql
\i util_meta/function/new_line.sql
\i util_meta/function/table_noun.sql
\i util_meta/function/proc_parameters.sql
\i util_meta/function/calling_parameters.sql
\i util_meta/function/boolean_casting.sql
\i util_meta/function/guess_private_proc.sql

-- Snippet functions
\i util_meta/function/snippet_declare_variables.sql
\i util_meta/function/snippet_documentation_block.sql

\i util_meta/function/snippet_log_params.sql
\i util_meta/function/snippet_object_comment.sql
\i util_meta/function/snippet_owners_and_grants.sql
\i util_meta/function/snippet_resolve_id.sql
\i util_meta/function/snippet_resolve_user_id.sql

\i util_meta/function/snippet_function_backmatter.sql
\i util_meta/function/snippet_function_frontmatter.sql
\i util_meta/function/snippet_procedure_backmatter.sql
\i util_meta/function/snippet_procedure_frontmatter.sql

\i util_meta/function/snippet_get_permissions.sql
\i util_meta/function/snippet_permissions_check.sql

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

\i util_meta/function/mk_priv_delete_procedure.sql
\i util_meta/function/mk_priv_insert_procedure.sql
\i util_meta/function/mk_priv_update_procedure.sql
\i util_meta/function/mk_priv_upsert_procedure.sql

\i util_meta/function/mk_delete_procedure.sql
\i util_meta/function/mk_insert_procedure.sql
\i util_meta/function/mk_update_procedure.sql
\i util_meta/function/mk_upsert_procedure.sql

--------------------------------------------------------------------------------
-- JSON utility functions
\i util_meta/function/json_identifier.sql

-- JSON snippet functions
\i util_meta/function/snippet_json_agg_build_object.sql
\i util_meta/function/snippet_json_build_object.sql

-- "Final" DDL generating functions for "JSON API" objects
\i util_meta/function/mk_json_view.sql
\i util_meta/function/mk_json_user_type.sql

\i util_meta/function/mk_json_function_wrapper.sql

--------------------------------------------------------------------------------
-- Testing functions
--\i util_meta/function/mk_test_procedure_wrapper.sql

--------------------------------------------------------------------------------
-- Ownership and Grants

GRANT USAGE ON SCHEMA util_meta TO util_meta_read ;

DO $$
    DECLARE
        r record ;
    BEGIN
        FOR r IN (
            SELECT schema_name,
                    object_name,
                    object_type
                FROM util_meta.objects
                WHERE schema_name = 'util_meta'
                    AND object_type NOT IN ( 'index' ) ) LOOP

            EXECUTE format ( 'ALTER %s %I.%I OWNER TO util_meta_owner ;', r.object_type, r.schema_name, r.object_name ) ;

            IF r.object_type IN ( 'view', 'table' ) THEN
                EXECUTE format ( 'GRANT SELECT ON %I.%I TO util_meta_read ;', r.schema_name, r.object_name ) ;
            ELSIF r.object_type IN ( 'function', 'procedure' ) THEN
                EXECUTE format ( 'GRANT EXECUTE ON %s %I.%I TO util_meta_read ;', r.object_type, r.schema_name, r.object_name ) ;
            END IF ;

        END LOOP ;
    END ;
$$ ;

