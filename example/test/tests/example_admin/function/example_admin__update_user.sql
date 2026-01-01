CREATE OR REPLACE FUNCTION test.example_admin__update_user (
    a_id in integer DEFAULT NULL,
    a_username in text DEFAULT NULL,
    a_first_name in text DEFAULT NULL,
    a_last_name in text DEFAULT NULL,
    a_email_address in text DEFAULT NULL,
    a_app_roles in text DEFAULT NULL,
    a_is_active in boolean DEFAULT NULL,
    a_act_user in text DEFAULT NULL,
    a_label in text DEFAULT NULL,
    a_should_pass in boolean DEFAULT NULL )
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, test
AS $$
DECLARE

    r record ;
    l_pg_cx text ;
    l_pg_ed text ;
    l_pg_ec text ;
    l_label text ;
    l_err text ;

BEGIN

    l_label := concat_ws ( ' ', 'pgTap test', quote_ident ( a_label ) ) ;

    IF coalesce ( a_should_pass, true ) THEN
        call util_log.log_begin ( concat_ws ( ' ', l_label, 'should pass' ) ) ;
    ELSE
        call util_log.log_begin ( concat_ws ( ' ', l_label, 'should fail' ) ) ;
    END IF ;

    call example_admin.update_user (
        a_id => a_id,
        a_username => a_username,
        a_first_name => a_first_name,
        a_last_name => a_last_name,
        a_email_address => a_email_address,
        a_app_roles => a_app_roles,
        a_is_active => a_is_active,
        a_act_user => a_act_user,
        a_err => l_err ) ;

    IF l_err IS NOT NULL THEN
        --RAISE NOTICE E'%', l_err ;
        call util_log.log_info ( concat_ws ( ' ', l_label, 'failed' ) ) ;
        RETURN false ;
    END IF ;

    FOR r IN (
        SELECT username,
                first_name,
                last_name,
                email_address,
                is_active
            FROM priv_example_admin.dv_user
            WHERE id = a_id ) LOOP

        IF a_username IS NOT NULL AND a_username IS DISTINCT FROM r.username THEN
            RAISE NOTICE E'username did not update. expected %, got %', a_username, r.username ;
            call util_log.log_info ( concat_ws ( ' ', l_label, 'failed' ) ) ;
            RETURN false ;
        END IF ;

        IF a_first_name IS NOT NULL AND a_first_name IS DISTINCT FROM r.first_name THEN
            RAISE NOTICE E'first_name did not update. expected %, got %', a_first_name, r.first_name ;
            call util_log.log_info ( concat_ws ( ' ', l_label, 'failed' ) ) ;
            RETURN false ;
        END IF ;

        IF a_last_name IS NOT NULL AND a_last_name IS DISTINCT FROM r.last_name THEN
            RAISE NOTICE E'last_name did not update. expected %, got %', a_last_name, r.last_name ;
            call util_log.log_info ( concat_ws ( ' ', l_label, 'failed' ) ) ;
            RETURN false ;
        END IF ;

        IF a_email_address IS NOT NULL AND a_email_address IS DISTINCT FROM r.email_address THEN
            RAISE NOTICE E'email_address did not update. expected %, got %', a_email_address, r.email_address ;
            call util_log.log_info ( concat_ws ( ' ', l_label, 'failed' ) ) ;
            RETURN false ;
        END IF ;

        IF a_is_active IS NOT NULL AND a_is_active IS DISTINCT FROM r.is_active THEN
            RAISE NOTICE E'is_active did not update. expected %, got %', a_is_active, r.is_active ;
            call util_log.log_info ( concat_ws ( ' ', l_label, 'failed' ) ) ;
            RETURN false ;
        END IF ;

    END LOOP ;

    call util_log.log_info ( concat_ws ( ' ', l_label, 'passed' ) ) ;
    RETURN true ;

EXCEPTION
    WHEN others THEN
        GET STACKED DIAGNOSTICS l_pg_cx = PG_CONTEXT,
                                l_pg_ed = PG_EXCEPTION_DETAIL,
                                l_pg_ec = PG_EXCEPTION_CONTEXT ;
        l_err := format ( '%s - %s:\n    %s\n     %s\n   %s', SQLSTATE, SQLERRM, l_pg_cx, l_pg_ed, l_pg_ec ) ;
        call util_log.log_exception ( l_err ) ;
        RAISE NOTICE E'EXCEPTION: %', l_err ;
        call util_log.log_info ( concat_ws ( ' ', l_label, 'failed' ) ) ;
        RETURN false ;
END ;
$$ ;
