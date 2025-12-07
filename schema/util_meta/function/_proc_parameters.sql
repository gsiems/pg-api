CREATE OR REPLACE FUNCTION util_meta._proc_parameters (
    a_action text DEFAULT NULL,
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_cast_booleans_as text DEFAULT NULL,
    a_insert_audit_columns text DEFAULT NULL,
    a_update_audit_columns text DEFAULT NULL )
RETURNS TABLE (
    schema_name text,
    object_name text,
    column_name text,
    column_data_type text,
    column_default text,
    ordinal_position integer,
    is_pk boolean,
    is_nk boolean,
    is_nullable boolean,
    is_audit_col boolean,
    audit_action text,
    is_audit_tmsp_col boolean,
    is_audit_user_col boolean,
    param_name text,
    param_direction text,
    param_data_type text,
    ref_param_name text,
    ref_data_type text,
    local_param_name text,
    resolve_id_function text,
    error_tag text,
    comments text,
    ref_param_comments text )
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _proc_parameters returns the data needed for specifying the parameter list for insert, update, and/or upsert procedures

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_action                       | in     | text       | The data management action that the procedure should perform {insert, update, upsert} |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure parameter list for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the procedure in |
| a_cast_booleans_as             | in     | text       | The (optional) csv list of "true,false" values to cast booleans as (if booleans are to be cast) |
| a_insert_audit_columns         | in     | text       | The (optional) csv list of insert audit columns (user created, timestamp created, etc.) that the database user doesn't directly edit |
| a_update_audit_columns         | in     | text       | The (optional) csv list of update audit columns (user updated, timestamp last updated, etc.) that the database user doesn't directly edit |

Do we want/need to be reconciling the needed procedure parameters with the view
for the specified table (names, order). For standard insert/update/upsert
procedures this probably isn't necessary but when we start creating JSON
procedures then being able to map the column names in the table view to the
procedure parameters becomes important. Or... should this (potential) problem
be kicked down the road and let the JSON procedure builder deal with it if
needed?

*/

WITH args AS (
    SELECT a_action AS action,
            a_object_schema AS table_schema,
            a_object_name AS table_name,
            a_ddl_schema AS target_schema,
            util_meta._resolve_parameter ( 'a_cast_booleans_as'::text, a_cast_booleans_as ) AS cast_booleans_as,
            util_meta._resolve_parameter (
                'a_insert_audit_columns'::text,
                a_insert_audit_columns ) AS insert_audit_columns,
            util_meta._resolve_parameter ( 'a_update_audit_columns'::text, a_update_audit_columns ) AS update_audit_columns
),
bools AS (
    SELECT CASE
                WHEN args.cast_booleans_as IS NULL THEN 'boolean'
                WHEN util_meta._resolve_parameter ( 'a_cast_booleans_as'::text, args.cast_booleans_as ) = '1,0'
                    THEN 'integer'
                ELSE 'text'
                END AS boolean_type
        FROM args
),
ins_audit_cols AS (
    SELECT trim ( regexp_split_to_table ( args.insert_audit_columns, ',' ) ) AS column_name
        FROM args
),
upd_audit_cols AS (
    SELECT trim ( regexp_split_to_table ( args.update_audit_columns, ',' ) ) AS column_name
        FROM args
),
audit_cols AS (
    SELECT column_name,
            'insert' AS audit_action
        FROM ins_audit_cols
    UNION
    SELECT column_name,
            'update' AS audit_action
        FROM upd_audit_cols
),
cbase AS (
    SELECT col.schema_name,
            col.object_name,
            col.column_name,
            col.data_type,
            col.ordinal_position,
            col.is_pk,
            col.is_nk,
            col.is_nullable,
            col.column_default,
            col.comments,
            ac.column_name IS NOT NULL AS is_audit_col,
            ac.audit_action,
            CASE
                WHEN ac.column_name IS NOT NULL AND ( col.data_type ~ 'time' OR col.data_type ~ 'date' ) THEN true
                ELSE false
                END AS is_audit_tmsp_col,
            CASE
                WHEN ac.column_name IS NOT NULL
                    AND ( col.data_type ~ 'text'
                        OR col.data_type ~ 'char'
                        OR col.data_type ~ 'int' )
                    THEN true
                ELSE false
                END AS is_audit_user_col
        FROM util_meta.columns col
        JOIN args
            ON ( args.table_schema = col.schema_name
                AND args.table_name = col.object_name )
        LEFT JOIN audit_cols ac
            ON ( ac.column_name = col.column_name )
),
base AS (
    SELECT col.schema_name,
            col.object_name,
            col.column_name,
            col.data_type AS column_data_type,
            CASE
                WHEN col.is_audit_tmsp_col AND col.data_type = 'date' THEN 'current_date'
                WHEN col.is_audit_tmsp_col AND col.data_type = 'time' THEN 'current_time'
                WHEN col.is_audit_tmsp_col THEN 'now ()'
                WHEN col.column_default IS NULL THEN NULL::text
                WHEN col.column_default ~ '^nextval'
                    AND args.action IN ( 'insert', 'upsert' )
                    AND col.column_default ~ '\.'
                    THEN 'nextval ( ' || quote_literal ( split_part ( col.column_default, '''', 2 ) ) || ' )'
                WHEN col.column_default ~ '^nextval' AND args.action IN ( 'insert', 'upsert' )
                    THEN 'nextval ( '
                        || quote_literal ( col.schema_name || '.' || split_part ( col.column_default, '''', 2 ) )
                        || ' )'
                ELSE col.column_default
                END AS column_default,
            --CASE
            --    WHEN col.is_pk AND col.column_name = 'id' AND col.column_default IS NOT NULL AND args.action IN ( 'insert', 'upsert' )
            --        THEN replace ( replace ( replace ( col.column_default, '::regclass', '' ), ')', ' )' ), '(', ' ( ' )
            --    WHEN col.is_audit_tmsp_col AND col.data_type = 'date' THEN 'current_date'
            --    WHEN col.is_audit_tmsp_col AND col.data_type = 'time' THEN 'current_time'
            --    WHEN col.is_audit_tmsp_col THEN 'now ()'
            --    ELSE col.column_default
            --    END AS column_default,
            col.ordinal_position,
            col.is_pk,
            col.is_nk,
            col.is_nullable,
            col.is_audit_col,
            col.audit_action,
            col.is_audit_tmsp_col,
            col.is_audit_user_col,
            CASE WHEN col.is_audit_col THEN NULL::text ELSE 'a_' || col.column_name END AS param_name,
            CASE
                WHEN col.is_audit_col THEN NULL::text
                WHEN NOT args.action IN ( 'insert', 'upsert' ) THEN 'in'
                WHEN NOT col.is_pk THEN 'in'
                -- column is pk and action is in ( 'insert', 'upsert' )
                WHEN col.column_name = 'id' THEN 'inout'
                WHEN (
                    SELECT count (*)
                        FROM cbase
                        WHERE is_pk ) = 1 AND (
                    SELECT count (*)
                        FROM util_meta.foreign_keys fk
                        WHERE fk.schema_name = col.schema_name
                            AND fk.table_name = col.object_name
                            AND fk.column_names = col.column_name ) = 0 THEN 'inout'
                --WHEN col.is_pk AND col.column_name = 'id' AND args.action IN ( 'insert', 'upsert' ) THEN 'inout' -- TODO: does it have to be 'id' ???
                ELSE 'in'
                END AS param_direction,
            CASE
                WHEN col.is_audit_col THEN NULL::text
                WHEN col.data_type = 'boolean' THEN coalesce ( bools.boolean_type, 'boolean' )
                ELSE col.data_type
                END AS param_data_type,
            CASE
                WHEN ref_data.ref_column_names IS NOT NULL THEN 'a_' || regexp_replace ( col.column_name, '_id$', '' )
                END AS ref_param_name,
            CASE WHEN ref_data.ref_column_names IS NOT NULL THEN 'text' END AS ref_data_type,
            CASE
                WHEN col.is_audit_user_col THEN 'l_acting_user_id'
                WHEN col.data_type = 'boolean' AND col.column_default IS NOT NULL THEN 'l_' || col.column_name
                WHEN col.data_type = 'boolean' AND bools.boolean_type <> col.data_type THEN 'l_' || col.column_name
                WHEN ref_data.ref_column_names IS NOT NULL THEN 'l_' || col.column_name
                END AS local_param_name,
            CASE
                WHEN ref_data.ref_column_names IS NOT NULL
                    THEN args.target_schema
                        || '.resolve_'
                        || regexp_replace ( ref_data.ref_table_name, '^[rs]t_', '' )
                        || '_id'
                END AS resolve_id_function,
            CASE
                WHEN ref_data.ref_column_names IS NOT NULL
                    THEN replace ( regexp_replace ( ref_data.ref_table_name, '^[rs]t_', '' ), '_', ' ' )
                END AS error_tag,
            trim ( col.comments ) AS comments
        FROM cbase col
        CROSS JOIN args
        CROSS JOIN bools
        LEFT JOIN util_meta.foreign_keys ref_data
            ON ( ref_data.schema_name = col.schema_name
                AND ref_data.table_name = col.object_name
                AND ref_data.column_names = col.column_name
                AND ref_data.ref_table_name ~ '^[rs]t_'
                --AND ref_data.ref_column_names = 'id' ) -- TODO: do we need to care that the name is 'id' ? or simply that the ref_column_names is a single column?
                AND ref_data.ref_column_names !~ ',' )
),
params AS (
    SELECT base.schema_name,
            base.object_name,
            base.column_name,
            base.column_data_type,
            base.column_default,
            base.ordinal_position,
            base.is_pk,
            base.is_nk,
            base.is_nullable,
            base.is_audit_col,
            base.audit_action,
            base.is_audit_tmsp_col,
            base.is_audit_user_col,
            base.param_name,
            base.param_direction,
            base.param_data_type,
            base.ref_param_name,
            base.ref_data_type,
            base.local_param_name,
            base.resolve_id_function,
            base.error_tag,
            base.comments,
            CASE
                WHEN base.ref_param_name IS NOT NULL
                    THEN 'The text associated with '
                        || base.param_name
                        || ' (as an alternative to providing '
                        || base.param_name
                        || ')'
                END AS ref_param_comments
        FROM base
    UNION
    SELECT base.schema_name,
            base.object_name,
            NULL::text AS column_name,
            NULL::text AS column_data_type,
            NULL::text AS column_default,
            max ( base.ordinal_position ) + 1 AS ordinal_position,
            false AS is_pk,
            false AS is_nk,
            false AS is_nullable,
            false AS is_audit_col,
            NULL::text AS audit_action,
            false AS is_audit_tmsp_col,
            false AS is_audit_user_col,
            'a_user' AS param_name,
            'in' AS param_direction,
            'text' AS param_data_type,
            NULL::text AS ref_param_name,
            NULL::text AS ref_data_type,
            NULL::text AS local_param_name,
            NULL::text AS resolve_id_function,
            NULL::text AS error_tag,
            'The ID or username of the user performing the ' || (
                SELECT action
                    FROM args ) AS comments,
            NULL::text AS ref_param_comments
        FROM base
        GROUP BY base.schema_name,
            base.object_name
    UNION
    SELECT base.schema_name,
            base.object_name,
            NULL::text AS column_name,
            NULL::text AS column_data_type,
            NULL::text AS column_default,
            max ( ordinal_position ) + 2 AS ordinal_position,
            false AS is_pk,
            false AS is_nk,
            true AS is_nullable,
            false AS is_audit_col,
            NULL::text AS audit_action,
            false AS is_audit_tmsp_col,
            false AS is_audit_user_col,
            'a_err' AS param_name,
            'inout' AS param_direction,
            'text' AS param_data_type,
            NULL::text AS ref_param_name,
            NULL::text AS ref_data_type,
            NULL::text AS local_param_name,
            NULL::text AS resolve_id_function,
            NULL::text AS error_tag,
            'The (business or database) error that was generated, if any' AS comments,
            NULL::text AS ref_param_comments
        FROM base
        GROUP BY base.schema_name,
            base.object_name
)
SELECT *
    FROM params
    ORDER BY ordinal_position ;

$$ ;
