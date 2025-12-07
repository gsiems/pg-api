CREATE OR REPLACE FUNCTION util_meta.mk_resolve_id_function (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_ddl_schema text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/**
Function mk_resolve_id_function generates a draft function for resolving reference table IDs

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the function for |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the function in (if different from the table schema) |
| a_owner                        | in     | text       | The (optional) role that is to be the owner of the function  |
| a_grantees                     | in     | text       | The (optional) csv list of roles that should be granted execute on the function |

The goal is to create a function that allows the user to supply either the ID or natural key for a reference
data table and have the function resolve and return the appropriate ID.

ASSERTIONS:

 * Reference tables have single-column synthetic primary keys

 * Reference tables have single-column natural keys (multi-column natural keys will require tweaking of the generated function)

 * The natural key for the reference table follows the table_name + '_nk' convention

Note that this should work for all rt_ and st_ tables

*/
DECLARE

    r record ;

    l_ddl_schema text ;
    l_doc_item text ;
    l_from_clause text ;
    l_func_name text ;
    l_nk_cast text ;
    l_nk_param text[] ;
    l_nk_type text[] ;
    l_nk_where text[] ;
    l_pk_cast text ;
    l_pk_col text ;
    l_pk_param text ;
    l_pk_where text ;
    l_result text ;
    l_return_type text ;
    l_select_clause text ;
    l_table_noun text ;

    l_local_vars util_meta.ut_parameters ;
    l_calling_params util_meta.ut_parameters ;

BEGIN

    -- TODO: for tables with multi-column PKs this needs to return all the columns in the key

    ----------------------------------------------------------------------------
    -- Ensure that the specified table exists
    IF NOT util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    ----------------------------------------------------------------------------
    -- ASSERTION: the table has a single-column primary key
    FOR r IN (
        SELECT count (*) AS kount
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
                AND is_pk ) LOOP

        IF r.kount = 0 THEN
            RETURN 'ERROR: no primary key found' ;
        ELSIF r.kount > 1 THEN
            RETURN 'ERROR: multi-column primary key found' ;
        END IF ;

    END LOOP ;

    ----------------------------------------------------------------------------
    l_ddl_schema := coalesce ( a_ddl_schema, a_object_schema ) ;

    -- ASSERTION: the table name is a noun that appropriately reflects the table contents
    l_table_noun := regexp_replace ( a_object_name, '^[a-z]t_', '' ) ;
    l_func_name := concat_ws (
        '_',
        'resolve',
        l_table_noun,
        'id' ) ;

    l_doc_item := replace ( l_table_noun, '_', ' ' ) ;
    IF substring ( l_doc_item FOR 1 ) IN ( 'a', 'e', 'i', 'o', 'u' ) THEN
        l_doc_item := 'the ID of an ' || l_doc_item ;
    ELSE
        l_doc_item := 'the ID of a ' || l_doc_item ;
    END IF ;

    ----------------------------------------------------------------------------
    l_local_vars := util_meta.append_parameter (
        a_parameters => l_local_vars,
        a_name => 'r',
        a_datatype => 'record' ) ;

    ----------------------------------------------------------------------------
    -- Determine the calling parameters block, signature, etc.
    FOR r IN (
        SELECT col.schema_name,
                col.object_name,
                col.column_name,
                col.is_pk,
                col.is_nk,
                col.ordinal_position,
                col.data_type,
                'in'::text AS direction,
                'a_' || col.column_name AS param_name,
                trim ( col.comments ) AS comments
            FROM util_meta.columns col
            WHERE col.schema_name = a_object_schema
                AND col.object_name = a_object_name
                AND ( col.is_pk
                    OR col.is_nk )
            ORDER BY col.ordinal_position ) LOOP

        ------------------------------------------------------------------------
        -- Calling parameters related
        IF r.param_name IS NOT NULL THEN

            l_calling_params := util_meta.append_parameter (
                a_parameters => l_calling_params,
                a_name => r.param_name,
                a_direction => r.direction,
                a_datatype => r.data_type,
                a_description => r.comments ) ;

            IF r.is_pk THEN

                l_return_type := r.data_type ;
                l_pk_col := r.column_name ;
                l_pk_param := r.param_name ;

                IF r.data_type ~ 'text' OR r.data_type ~ 'char' THEN
                    l_pk_where := concat_ws (
                        ' ',
                        r.column_name,
                        'IS NOT DISTINCT FROM',
                        'trim (',
                        r.param_name,
                        ')' ) ;
                ELSE
                    l_pk_where := concat_ws (
                        ' ',
                        r.column_name,
                        'IS NOT DISTINCT FROM',
                        r.param_name ) ;
                END IF ;

            ELSIF r.is_nk THEN

                IF r.data_type ~ 'text' OR r.data_type ~ 'char' THEN
                    l_nk_where := array_append (
                        l_nk_where,
                        concat_ws (
                            ' ',
                            r.column_name,
                            'IS NOT DISTINCT FROM',
                            'trim (',
                            r.param_name,
                            ')' ) ) ;
                ELSE
                    l_nk_where := array_append (
                        l_nk_where,
                        concat_ws (
                            ' ',
                            r.column_name,
                            'IS NOT DISTINCT FROM',
                            r.param_name ) ) ;
                END IF ;

                l_nk_param := array_append ( l_nk_param, r.param_name ) ;
                l_nk_type := array_append ( l_nk_type, r.data_type ) ;

            END IF ;

        END IF ;

    END LOOP ;

    l_result := concat_ws (
        util_meta.new_line (),
        l_result,
        util_meta.snippet_function_frontmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_return_type => l_return_type,
            --a_returns_set => false,
            a_calling_parameters => l_calling_params ),
        util_meta.snippet_documentation_block (
            a_object_name => l_func_name,
            a_object_type => 'function',
            a_object_purpose => 'resolves ' || l_doc_item,
            a_calling_parameters => l_calling_params ),
        util_meta.snippet_declare_variables ( a_variables => l_local_vars ),
        '',
        'BEGIN' ) ;

    l_select_clause := util_meta.indent ( 2 ) || 'SELECT ' || l_pk_col ;
    l_from_clause := util_meta.indent ( 3 ) || 'FROM ' || a_object_schema || '.' || a_object_name ;

    ----------------------------------------------------------------------------
    -- Go for the natural key match first
    IF array_length ( l_nk_where, 1 ) > 0 THEN

        l_result := concat_ws (
            util_meta.new_line (),
            l_result,
            '',
            util_meta.indent ( 1 ) || '-- Search for a match on the natural key',
            util_meta.indent ( 1 ) || 'FOR r IN (',
            l_select_clause,
            l_from_clause,
            util_meta.indent ( 3 )
                || 'WHERE '
                || array_to_string ( l_nk_where, util_meta.new_line () || util_meta.indent ( 4 ) || 'AND ' )
                || ' ) LOOP',
            '',
            util_meta.indent ( 2 ) || 'RETURN r.' || l_pk_col || ' ;',
            '',
            util_meta.indent ( 1 ) || 'END LOOP ;' ) ;

    END IF ;

    ----------------------------------------------------------------------------
    -- Next, attempt the primary key match
    l_result := concat_ws (
        util_meta.new_line (),
        l_result,
        '',
        util_meta.indent ( 1 ) || '-- Search for a match on the primary key',
        util_meta.indent ( 1 ) || 'FOR r IN (',
        l_select_clause,
        l_from_clause,
        util_meta.indent ( 3 ) || 'WHERE ' || l_pk_where || ' ) LOOP',
        '',
        util_meta.indent ( 2 ) || 'RETURN r.' || l_pk_col || ' ;',
        '',
        util_meta.indent ( 1 ) || 'END LOOP ;' ) ;

    ----------------------------------------------------------------------------
    -- Finally, if there is a single-column natural key then attempt the primary
    -- key match on the natural key parameter
    IF array_length ( l_nk_where, 1 ) = 1 THEN

        IF l_return_type = l_nk_type[1] THEN
            l_pk_cast := l_pk_col ;
        ELSE
            l_pk_cast := l_pk_col || '::' || l_nk_type[1] ;
        END IF ;

        IF l_nk_type[1] ~ 'text' || l_nk_type[1] ~ 'char' THEN
            l_nk_cast := 'trim ( ' || l_nk_param[1] || ' )' ;
        ELSE
            l_nk_cast := l_nk_param[1] ;
        END IF ;

        l_result := concat_ws (
            util_meta.new_line (),
            l_result,
            '',
            util_meta.indent ( 1 ) || '-- Search for a match on the natural key parameter matching the primary key',
            util_meta.indent ( 1 ) || 'FOR r IN (',
            l_select_clause,
            l_from_clause,
            util_meta.indent ( 3 ) || concat_ws (
                ' ',
                'WHERE',
                l_pk_param,
                'IS NULL' ),
            util_meta.indent ( 4 )
                || concat_ws (
                    ' ',
                    'AND',
                    l_pk_cast,
                    'IS NOT DISTINCT FROM',
                    l_nk_cast,
                    ')',
                    'LOOP' ),
            '',
            util_meta.indent ( 2 ) || 'RETURN r.' || l_pk_col || ' ;',
            '',
            util_meta.indent ( 1 ) || 'END LOOP ;' ) ;

    END IF ;

    ----------------------------------------------------------------------------
    l_result := concat_ws (
        util_meta.new_line (),
        l_result,
        '',
        util_meta.indent ( 1 ) || 'RETURN null::' || l_return_type || ' ;',
        util_meta.snippet_function_backmatter (
            a_ddl_schema => l_ddl_schema,
            a_function_name => l_func_name,
            a_language => 'plpgsql',
            a_comment => 'Returns ' || l_doc_item,
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_calling_parameters => l_calling_params ) ) ;

    RETURN util_meta.cleanup_whitespace ( l_result ) ;

END ;
$$ ;
