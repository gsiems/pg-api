CREATE OR REPLACE FUNCTION util_meta.snippet_json_agg_build_object (
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
Function snippet_json_agg_build_object generates a json_agg wrapped json_build_object function call query for a table or view

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_indents                      | in     | integer    | The (optional) number of indents to add to the code snippet (default 0) |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table/view to wrap with the json view |
| a_object_name                  | in     | text       | The (name of the) table/view to wrap with the JSON view |
| a_where_columns                | in     | text       | The (csv list of) column names to filter and group by |
| a_exclude_columns              | in     | text       | The (optional)(csv list of) column names to exclude from the json object |

*/
DECLARE

    r record ;

    l_full_object_name text ;
    l_object_alias text := 't0' ;
    l_result text ;
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

    ----------------------------------------------------------------------------
    FOR r IN (
        SELECT trim ( regexp_split_to_table ( a_where_columns, ',' ) ) AS column_name ) LOOP

        l_filter_cols := array_append ( l_filter_cols, r.column_name ) ;

    END LOOP ;

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

    l_select_cols := array_append ( l_select_cols, 'json_agg ( json_build_object ('
        || util_meta.new_line () || util_meta.indent (l_indents+5) ||  array_to_string ( l_jbo_columns, ',' || util_meta.new_line () || util_meta.indent (l_indents+5) ) || ' ) ) AS ' || l_jbo_alias ) ;

    l_result := concat_ws ( util_meta.new_line (),
        'SELECT ' || array_to_string ( l_select_cols, ',' || util_meta.new_line () || util_meta.indent (l_indents+2) ),
        util_meta.indent (l_indents+1) || concat_ws ( ' ', 'FROM', l_full_object_name, l_object_alias ),
        util_meta.indent (l_indents+1) || 'WHERE ' || array_to_string ( l_where_cols, ',' || util_meta.new_line () || util_meta.indent (l_indents+3) || 'AND ' ),
        util_meta.indent (l_indents+1) || 'GROUP BY ' || array_to_string ( l_group_cols, ',' || util_meta.new_line () || util_meta.indent (l_indents+3) )
        ) ;

    RETURN l_result ;

END ;
$$ ;
