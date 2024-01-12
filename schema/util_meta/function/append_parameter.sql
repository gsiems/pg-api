CREATE OR REPLACE FUNCTION util_meta.append_parameter (
    a_parameters in util_meta.ut_parameters,
    a_name in text default null,
    a_direction in text default null,
    a_datatype in text default null,
    a_description in text default null )
RETURNS util_meta.ut_parameters
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function append_parameter appends a parameter definition to the list of parameters and returns the updated list

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_parameters                   | in     | util_meta.ut_parameters | The list of parameters to append to   |
| a_name                         | in     | text       | The name of the parameter being appended           |
| a_direction                    | in     | text       | The directionality of the parameter {in, out, inout} (defaults to 'in') |
| a_datatype                     | in     | text       | The datatype for the parameter (defaults to 'anytype') |
| a_description                  | in     | text       | The description of the parameter                   |

*/
DECLARE

    l_ret util_meta.ut_parameters ;

BEGIN

    l_ret := a_parameters ;

    l_ret.names := array_append ( a_parameters.names, a_name ) ;
    l_ret.directions := array_append ( a_parameters.directions, coalesce ( a_direction, 'in' ) ) ;
    l_ret.datatypes := array_append ( a_parameters.datatypes, coalesce ( a_datatype, 'anytype' ) ) ;
    l_ret.descriptions := array_append ( a_parameters.descriptions, coalesce ( a_description, 'TBD' ) ) ;
    l_ret.args := array_append ( a_parameters.args, concat_ws ( ' ', a_name, '=>', a_name ) ) ;

    RETURN l_ret ;

END ;
$$ ;
