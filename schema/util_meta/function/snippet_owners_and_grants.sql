CREATE OR REPLACE FUNCTION util_meta.snippet_owners_and_grants (
    a_ddl_schema text default null,
    a_object_name text default null,
    a_object_type text default null,
    a_owner text default null,
    a_grantees text default null,
    a_calling_parameters util_meta.ut_parameters default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_owners_and_grants generates the pl/pg-sql code snippet for setting ownership and granting execute

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the object in   |
| a_object_name                  | in     | text       | The (name of the) object to create                 |
| a_object_type                  | in     | text       | The type of object to create                       |
| a_owner                        | in     | text       | The role that is to be the owner of the procedure  |
| a_grantees                     | in     | text       | The csv list of roles that should be granted execute on the procedure |
| a_calling_parameters           | in     | ut_parameters | The (optional) list of calling parameters       |

*/
DECLARE

    r record ;
    l_return text ;
    l_alter_sig text ;
    l_grant_sig text ;
    l_priv text ;
    l_owner text ;

BEGIN

    ----------------------------------------------------------------------------
    -- check parameters/defaults
    l_owner = util_meta.resolve_parameter ( 'a_owner'::text, a_owner ) ;

    ----------------------------------------------------------------------------
    l_alter_sig := concat_ws ( ' ', upper ( a_object_type ), a_ddl_schema || '.' || a_object_name ) ;

    IF upper ( a_object_type ) IN ( 'FUNCTION', 'PROCEDURE' ) THEN

        l_alter_sig := concat_ws ( ' ', l_alter_sig, '(', array_to_string ( a_calling_parameters.datatypes, ', ' ), ')' ) ;
        l_grant_sig := l_alter_sig ;
        l_priv := 'EXECUTE' ;

    ELSIF upper ( a_object_type ) IN ( 'TABLE', 'VIEW' ) THEN

        l_grant_sig := a_ddl_schema || '.' || a_object_name ;
        l_priv := 'SELECT' ;

    ELSIF upper ( a_object_type ) IN ( 'TYPE' ) THEN

        l_grant_sig := a_ddl_schema || '.' || a_object_name ;
        l_priv := 'USAGE' ;

    END IF ;

    IF l_owner IS NOT NULL THEN

        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            '',
            concat_ws ( ' ', 'ALTER', l_alter_sig, 'OWNER TO', l_owner, ';' ) ) ;

    END IF ;

    FOR r IN (
        SELECT trim ( regexp_split_to_table ( a_grantees, ',' ) ) AS grantee ) LOOP

        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            '',
            concat_ws ( ' ', 'GRANT', l_priv, 'ON', l_grant_sig, 'TO', r.grantee, ';' ) ) ;

    END LOOP ;

    RETURN l_return ;

END ;
$$ ;
