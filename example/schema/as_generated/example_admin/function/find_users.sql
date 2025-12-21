CREATE OR REPLACE FUNCTION example_admin.find_users (
    a_act_user in text DEFAULT NULL,
    a_search_term in text DEFAULT NULL )
RETURNS SETOF priv_example_admin.dv_user
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, example_admin
AS $$
/**
Function find_users Returns the list of matching user entries

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_act_user                     | in     | text       | The ID or username of the user doing the search    |
| a_search_term                  | in     | text       | The string to search for                           |

*/
DECLARE

    l_has_permission boolean ;

BEGIN

    -- TODO: review this as different applications may have different permissions models.
    -- TODO: verify the columns to search on
    -- ASSERTION: the permissions model is table (as opposed to row) based.

    l_has_permission := example_admin.can_do (
        a_user => a_act_user,
        a_action => 'select',
        a_object_type => 'user',
        a_id => null ) ;

    RETURN QUERY
        WITH base AS (
            SELECT id,
                    username
                FROM priv_example_admin.dv_user
                WHERE l_has_permission
        ),
        found AS (
            SELECT id
                FROM base
                WHERE ( ( a_search_term IS NOT NULL
                            AND trim ( a_search_term ) <> ''
                            AND lower ( base::text ) ~ lower ( a_search_term ) )
                        OR ( trim ( coalesce ( a_search_term, '' ) ) = '' ) )
        )
        SELECT de.*
            FROM priv_example_admin.dv_user de
            JOIN found
                ON ( found.id = de.id ) ;

END ;
$$ ;

