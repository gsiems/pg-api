CREATE OR REPLACE FUNCTION priv_example_admin.resolve_user_id (
    a_id in integer DEFAULT NULL,
    a_username in text DEFAULT NULL )
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, priv_example_admin
AS $$
/**
Function resolve_user_id resolves the ID of an user

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_id                           | in     | integer    | The system generated ID (primary key) for a user.  |
| a_username                     | in     | text       | The login username.                                |

*/
DECLARE

    r record ;

BEGIN

    -- Search for a match on the natural key
    FOR r IN (
        SELECT id
            FROM example_data.dt_user
            WHERE username IS NOT DISTINCT FROM trim ( a_username ) ) LOOP

        RETURN r.id ;

    END LOOP ;

    -- Search for a match on the primary key
    FOR r IN (
        SELECT id
            FROM example_data.dt_user
            WHERE id IS NOT DISTINCT FROM a_id ) LOOP

        RETURN r.id ;

    END LOOP ;

    -- Search for a match on the natural key parameter matching the primary key
    FOR r IN (
        SELECT id
            FROM example_data.dt_user
            WHERE a_id IS NULL
                AND id::text IS NOT DISTINCT FROM a_username ) LOOP

        RETURN r.id ;

    END LOOP ;

    RETURN null::integer ;

END ;
$$ ;

