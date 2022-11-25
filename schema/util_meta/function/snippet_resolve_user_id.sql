CREATE OR REPLACE FUNCTION util_meta.snippet_resolve_user_id (
    a_indents integer default null,
    a_check_result boolean default null )
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
/**
Function snippet_resolve_user_id    generates the pl/pg-sql code snippet for logging the calling parameters to a function or procedure

| Parameter                      | In/Out | Datatype   | Remarks                                            |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_indents                      | in     | integer    | The number of indents to add to the code snippet (default 1) |
| a_check_result                 | in     | boolean    | Indicates if there should be a cehck of the return value |

*/
DECLARE

    r record ;

    l_indents integer ;
    l_log_err_line integer ;
    l_return text ;

BEGIN

    l_indents := coalesce ( a_indents, 1 ) ;

    ----------------------------------------------------------------------------
    -- ASSERTION: There will be a dt_user table of some sort and this table
    -- will have a single-column primary key of an "id" variety, therefore there
    -- will also be a resolve_user_id function of some sort.
    FOR r IN (
        SELECT full_object_name
            FROM util_meta.objects
            WHERE object_name = 'resolve_user_id' ) LOOP

        l_return := util_meta.indent ( l_indents ) || 'l_acting_user_id := ' || r.full_object_name || ' ( a_user => a_user ) ;' ;

        IF coalesce ( a_check_result, true ) THEN

            ----------------------------------------------------------------------------
            -- Check that util_log schema exists
            IF util_meta.is_valid_object ( 'util_log', 'log_exception', 'procedure' ) THEN
                l_log_err_line := util_meta.indent ( l_indents + 1 ) || 'call util_log.log_exception ( a_err ) ;' ;
            END IF ;

            l_return := concat_ws ( util_meta.new_line (),
                    l_return,
                    util_meta.indent ( l_indents ) || 'IF l_acting_user_id IS NULL THEN',
                    util_meta.indent ( l_indents + 1 ) || 'a_err := ''No, or invalid, user specified'' ;',
                    l_log_err_line,
                    util_meta.indent ( l_indents + 1 ) || 'RETURN ;',
                    util_meta.indent ( l_indents ) || 'END IF ;' ) ;

        END IF ;

        RETURN l_return ;

    END LOOP ;

    RETURN 'TODO: l_acting_user_id := ' ;

END ;
$$ ;
