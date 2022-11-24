CREATE OR REPLACE FUNCTION util_meta.snippet_owners_and_grants (
    a_ddl_schema text default null,
    a_object_name text default null,
    a_object_type text default null,
    a_owner text default null,
    a_grantees text default null,
    a_datatypes text[] default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_owners_and_grants generates the pl/pg-sql code snippet for setting ownership and granting execute

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_ddl_schema                   | in     | text       | The (name of the) schema to create the object in   |
| a_object_name                  | in     | text       | The (name of the) object to create                 |
| a_object_type                  | in     | text       | The type of object to create                       |
| a_owner                        | in     | text       | The role that is to be the owner of the procedure  |
| a_grantees                     | in     | text       | The csv list of roles that should be granted execute on the procedure |
| a_datatypes                    | in     | text[]     | The list of the datatypes for the parameters       |

*/
DECLARE

    r record ;
    l_return text ;
    l_sig text ;
    l_priv text ;

BEGIN

    l_sig := concat_ws ( ' ', upper ( a_object_type ), a_ddl_schema || '.' || a_object_name ) ;

    IF upper ( a_object_type ) IN ( 'FUNCTION', 'PROCEDURE' ) THEN

        l_sig := concat_ws ( ' ', l_sig, '(', array_to_string ( a_datatypes, ', ' ), ')' ) ;
        l_priv := 'EXECUTE' ;

    ELSIF upper ( a_object_type ) IN ( 'TABLE', 'VIEW' ) THEN

        l_priv := 'SELECT' ;

    ELSIF upper ( a_object_type ) IN ( 'TYPE' ) THEN

        l_priv := 'USAGE' ;

    END IF ;

    IF a_owner IS NOT NULL THEN

        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            '',
            concat_ws ( ' ', 'ALTER', l_sig, 'OWNER TO', a_owner, ';' ) ) ;

    END IF ;

    FOR r IN (
        SELECT trim ( regexp_split_to_table ( a_grantees, ',' ) ) AS grantee ) LOOP

        l_return := concat_ws ( util_meta.new_line (),
            l_return,
            '',
            concat_ws ( ' ', 'GRANT', l_priv, 'ON', l_sig, 'TO', r.grantee, ';' ) ) ;

    END LOOP ;

    RETURN l_return ;

END ;
$$ ;
