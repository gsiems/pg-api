CREATE OR REPLACE FUNCTION util_meta.calling_parameters (
    a_object_schema text DEFAULT NULL,
    a_object_name text DEFAULT NULL,
    a_object_type text DEFAULT NULL )
RETURNS TABLE (
    schema_name text,
    object_name text,
    object_type text,
    param_name text,
    data_type text,
    param_default text,
    param_direction text,
    arg_position bigint,
    local_var_name text,
    column_name text,
    comments text )
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function calling_parameters returns the calling parameter data for the specified function/procedure

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_object_schema                | in     | text       | The (name of the) schema that contains the table   |
| a_object_name                  | in     | text       | The (name of the) table to create the procedure parameter list for |
| a_object_type                  | in     | text       | The type {function, procedure} of the object       |

*/

WITH p1 AS (
    SELECT objects.schema_name,
            objects.object_name,
            objects.object_type,
            trim ( regexp_split_to_table ( objects.calling_arguments, ',' ) ) AS param,
            row_number () OVER () AS arg_position
        FROM util_meta.objects
        WHERE objects.schema_name = a_object_schema
            AND objects.object_name = a_object_name
            AND objects.object_type = a_object_type
),
p2 AS (
    SELECT p1.schema_name,
            p1.object_name,
            p1.object_type,
            ( regexp_match ( p1.param, ' DEFAULT (.+)$', 'i' ) )[1] AS param_default,
            coalesce ( ( regexp_match ( lower ( p1.param ), '^(inout|in|out) ' ) )[1], 'in' ) AS param_direction,
            regexp_replace (
                regexp_replace (
                    p1.param,
                    '^(INOUT|IN|OUT) ',
                    '',
                    'i' ),
                ' DEFAULT .+$',
                '',
                'i' ) AS remainder,
            p1.arg_position
        FROM p1
),
p3 AS (
    SELECT schema_name,
            object_name,
            object_type,
            split_part ( remainder, ' ', 1 ) AS param_name,
            regexp_replace ( remainder, '^[^ ]+ ', '' ) AS data_type,
            param_default,
            param_direction,
            arg_position
        FROM p2
)
SELECT schema_name,
        object_name,
        object_type,
        param_name,
        data_type,
        param_default,
        param_direction,
        arg_position,
        regexp_replace ( param_name, '^a_', 'l_' ) AS local_var_name,
        regexp_replace ( param_name, '^a_', '' ) AS column_name,
        CASE
            WHEN param_name = 'a_user' THEN 'The ID or username of the user performing the action'
            WHEN param_name = 'a_err' THEN 'The (business or database) error that was generated, if any'
            WHEN param_name = 'a_search_term' THEN 'The string to search for'
            END AS comments
    FROM p3
    ORDER BY arg_position ;

$$ ;
