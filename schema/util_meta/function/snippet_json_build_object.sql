CREATE OR REPLACE FUNCTION util_meta.snippet_json_build_object (
    a_indents integer default null,
    a_object_schema text default null,
    a_object_name text default null,
    a_where_columns text default null,
    a_exclude_columns text default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_json_build_object generates a json_build_object function call query for a table or view

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_indents                      | in     | integer    | The (optional) number of indents to add to the code snippet (default 0) |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to wrap with the json view |
| a_object_name                  | in     | text       | The (name of the) table/view to wrap with the JSON view |
| a_where_columns                | in     | text       | The (optional) (csv list of) column names to filter by |
| a_exclude_columns              | in     | text       | The (optional)(csv list of) column names to exclude from the json object |

*/
DECLARE

    r record ;

    l_full_object_name text ;
    l_object_alias text := 't0' ;
    l_result text ;
    l_table_name text ;
    l_table_schema text ;
    l_jbo_columns text[] ;
    l_object_type text ;
    l_filter_cols text[] ;
    l_select_cols text[] ;
    l_group_cols text[] ;
    l_where_cols text[] ;
    l_indents integer ;
    l_jbo_alias text := 'TBD' ;
    l_exclude_columns text[] ;

BEGIN

    --------------------------------------------------------------------
    -- Ensure that the specified object is valid and if the object is a view or a table
    IF util_meta.is_valid_object ( a_object_schema, a_object_name, 'view' ) THEN
        l_object_type := 'view' ;
    END IF ;

    IF l_object_type IS NULL THEN
        IF util_meta.is_valid_object ( a_object_schema, a_object_name, 'table' ) THEN
            l_object_type := 'table' ;
        END IF ;
    END IF ;

    IF l_object_type IS NULL THEN
        RETURN 'ERROR: invalid object' ;
    END IF ;

    IF a_where_columns IS NULL THEN

        ----------------------------------------------------------------------------
        -- Determine the table
        IF l_object_type = 'table' THEN

            l_table_schema := a_object_schema ;
            l_table_name := a_object_name ;

        ELSE -- it's a view

            FOR r IN (
                SELECT schema_name,
                        object_name
                    FROM util_meta.dependencies
                    WHERE object_type = 'table'
                        AND dep_schema_name = a_object_schema
                        AND dep_object_name = a_object_name
                        AND object_name = regexp_replace ( a_object_name, '^([drs])[tv]_', '\1t_' ) ) LOOP

                l_table_schema := r.schema_name ;
                l_table_name := r.object_name ;

            END LOOP ;

        END IF ;


        -- Get the PK columns for the table
        IF l_table_name IS NOT NULL THEN

            -- ASSERTION if the object is a table then all is good,
            --  If the object is a view then the column names will match between the view and the base table
            FOR r IN (
                SELECT column_name,
                        l_object_alias || '.' || column_name AS full_column_name,
                        ordinal_position,
                        is_pk
                    FROM util_meta.columns
                    WHERE schema_name = l_table_schema
                        AND object_name = l_table_name
                        AND is_pk
                    ORDER BY ordinal_position ) LOOP

                l_filter_cols := array_append ( l_filter_cols, r.column_name ) ;

            END LOOP ;

        END IF ;

    ELSE

        FOR r IN (
            SELECT trim ( regexp_split_to_table ( a_where_columns, ',' ) ) AS column_name ) LOOP

            l_filter_cols := array_append ( l_filter_cols, r.column_name ) ;

        END LOOP ;

    END IF ;

    FOR r IN (
        SELECT trim ( regexp_split_to_table ( a_exclude_columns, ',' ) ) AS column_name ) LOOP

        l_exclude_columns := array_append ( l_exclude_columns, r.column_name ) ;

    END LOOP ;

    --------------------------------------------------------------------
    FOR r IN (
        SELECT column_name,
                l_object_alias || '.' || column_name AS full_column_name,
                util_meta.json_identifier ( column_name ) AS json_alias,
                ordinal_position
            FROM util_meta.columns
            WHERE schema_name = a_object_schema
                AND object_name = a_object_name
            ORDER BY ordinal_position ) LOOP

        IF r.column_name <> ANY ( l_exclude_columns ) THEN

            IF r.column_name = r.json_alias THEN
                l_jbo_columns := array_append ( l_jbo_columns, concat_ws ( ', ', r.json_alias, r.full_column_name ) ) ;
            ELSE
                l_jbo_columns := array_append ( l_jbo_columns, concat_ws ( ', ', quote_literal ( r.json_alias ), r.full_column_name ) ) ;
            END IF ;

        END IF ;

        IF r.column_name = ANY ( l_filter_cols ) THEN

            l_select_cols := array_append ( l_select_cols, r.full_column_name ) ;
            l_where_cols := array_append ( l_where_cols, concat_ws ( ' ', r.full_column_name, '=', 'a_' || r.column_name ) ) ;
            l_group_cols := array_append ( l_group_cols, r.full_column_name ) ;

        END IF ;

    END LOOP ;

    l_indents := coalesce ( a_indents, 0 ) ;
    l_full_object_name := concat_ws ( '.', a_object_schema, a_object_name ) ;

    l_select_cols := array_append ( l_select_cols, 'json_build_object ('
        || util_meta.new_line () || util_meta.indent (l_indents+4) ||  array_to_string ( l_jbo_columns, ',' || util_meta.new_line () || util_meta.indent (l_indents+4) ) || ' ) AS ' || l_jbo_alias ) ;

    l_result := concat_ws ( util_meta.new_line (),
        'SELECT ' || array_to_string ( l_select_cols, ',' || util_meta.new_line () || util_meta.indent (l_indents+2) ),
        util_meta.indent (l_indents+1) || concat_ws ( ' ', 'FROM', l_full_object_name, l_object_alias ) ) ;

    IF array_length ( l_where_cols, 1 ) > 0 THEN

        l_result := concat_ws ( util_meta.new_line (),
            l_result,
            util_meta.indent (l_indents+1) || 'WHERE ' || array_to_string ( l_group_cols, ',' || util_meta.new_line () || util_meta.indent (l_indents+3) || 'AND ' ) ) ;

    END IF ;

    RETURN l_result ;

END ;
$$ ;
