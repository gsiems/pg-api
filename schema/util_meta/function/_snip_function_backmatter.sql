CREATE OR REPLACE FUNCTION util_meta._snip_function_backmatter (
    a_ddl_schema text DEFAULT NULL,
    a_function_name text DEFAULT NULL,
    a_language text DEFAULT NULL,
    a_comment text DEFAULT NULL,
    a_owner text DEFAULT NULL,
    a_grantees text DEFAULT NULL,
    a_calling_parameters util_meta.ut_parameters DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function _snip_function_backmatter generates the pl/pg-sql code snippet for the end of a function

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) module (and hence schema) to create the function in (if different from the table schema) |
| a_function_name                | in     | text       | The (name of the) function  to create              |
| a_language                     | in     | text       | The language that the function is written in (defaults to plpgsql) |
| a_comment                      | in     | text       | The text of the comment for the object             |
| a_owner                        | in     | text       | The role that is to be the owner of the function   |
| a_grantees                     | in     | text       | The csv list of roles that should be granted execute on the function |
| a_calling_parameters           | in     | ut_parameters | The list of calling parameters                  |

*/
DECLARE

    l_return text ;

BEGIN

    IF coalesce ( a_language, 'plpgsql' ) = 'plpgsql' THEN

        l_return := concat_ws (
            util_meta._new_line (),
            '',
            'END ;',
            '$' || '$ ;' ) ;

    ELSE

        l_return := concat_ws ( util_meta._new_line (), '', '$' || '$ ;' ) ;

    END IF ;

    l_return := concat_ws (
        util_meta._new_line (),
        l_return,
        '',
        util_meta._snip_owners_and_grants (
            a_ddl_schema => a_ddl_schema,
            a_object_name => a_function_name,
            a_object_type => 'function',
            a_owner => a_owner,
            a_grantees => a_grantees,
            a_calling_parameters => a_calling_parameters ),
        '',
        util_meta._snip_object_comment (
            a_ddl_schema => a_ddl_schema,
            a_object_name => a_function_name,
            a_object_type => 'function',
            a_comment => a_comment,
            a_calling_parameters => a_calling_parameters ),
        '' ) ;

    RETURN l_return ;

END ;
$$ ;
