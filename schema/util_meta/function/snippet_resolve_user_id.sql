CREATE OR REPLACE FUNCTION util_meta.snippet_resolve_user_id (
    a_indents integer DEFAULT NULL,
    a_user_id_var text DEFAULT NULL,
    a_user_id_param text DEFAULT NULL,
    a_check_result boolean DEFAULT NULL )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, util_meta
AS $$
/* *
Function snippet_resolve_user_id generates the pl/pg-sql code snippet for logging the calling parameters to a function or procedure

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_indents                      | in     | integer    | The number of indentations to prepend to each line of the code snippet (default 1) |
| a_user_id_var                  | in     | text       | The name of the user ID variable to populate (default l_acting_user_id) |
| a_user_id_param                | in     | text       | The parameter to check the user Id for (default a_user) |
| a_check_result                 | in     | boolean    | Indicates if there should be a check of the return value |

*/
DECLARE

    r record ;

    l_indents integer ;
    l_log_err_line text ;
    l_return text ;
    l_user_id_param text ;
    l_user_id_var text ;

BEGIN

    l_indents := coalesce ( a_indents, 1 ) ;
    l_user_id_var := coalesce ( a_user_id_var, 'l_acting_user_id' ) ;
    l_user_id_param := coalesce ( a_user_id_param, 'a_user' ) ;

    ----------------------------------------------------------------------------
    -- ASSERTION: There will be a dt_user table of some sort and this table
    -- will have a single-column primary key of an "id" variety, therefore there
    -- will also be a resolve_user_id function of some sort.
    FOR r IN (
        SELECT full_object_name
            FROM util_meta.objects
            WHERE object_name = 'resolve_user_id' ) LOOP

        l_return := util_meta.indent ( l_indents )
            || l_user_id_var
            || ' := '
            || r.full_object_name
            || ' ( a_user => '
            || l_user_id_param
            || ' ) ;' ;

        IF coalesce ( a_check_result, true ) THEN

            ----------------------------------------------------------------------------
            -- Check that util_log schema exists
            IF util_meta.is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
                l_log_err_line := util_meta.indent ( l_indents + 1 ) || 'call util_log.log_exception ( a_err ) ;' ;
            END IF ;

            l_return := concat_ws (
                util_meta.new_line (),
                l_return,
                util_meta.indent ( l_indents ) || 'IF ' || l_user_id_var || ' IS NULL THEN',
                util_meta.indent ( l_indents + 1 ) || 'a_err := ''No, or invalid, user specified'' ;',
                l_log_err_line,
                util_meta.indent ( l_indents + 1 ) || 'RETURN ;',
                util_meta.indent ( l_indents ) || 'END IF ;' ) ;

        END IF ;

        RETURN l_return ;

    END LOOP ;

    RETURN '-- TODO: (schema name?) '
        || l_user_id_var
        || ' := resolve_user_id ( a_user => '
        || l_user_id_param
        || ' ) ;' ;

END ;
$$ ;
