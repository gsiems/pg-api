CREATE OR REPLACE FUNCTION util_meta.append_parameter (
    a_parameters in util_meta.ut_parameters,
    a_name in text default null,
    a_direction in text default null,
    a_datatype in text default null,
    a_comment in text default null )
RETURNS util_meta.ut_parameters
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE

    l_ret util_meta.ut_parameters ;

BEGIN

    l_ret := a_parameters ;

    l_ret.names := array_append ( a_parameters.names, a_name ) ;
    l_ret.directions := array_append ( a_parameters.directions, coalesce ( a_direction, 'in' ) ) ;
    l_ret.datatypes := array_append ( a_parameters.datatypes, coalesce ( a_datatype, 'anytype' ) ) ;
    l_ret.comments := array_append ( a_parameters.comments, coalesce ( a_comment, 'TBD' ) ) ;
    l_ret.args := array_append ( a_parameters.args, concat_ws ( ' ', a_name, '=>', a_name ) ) ;

    RETURN l_ret ;

END ;
$$ ;
