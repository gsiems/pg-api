CREATE OR REPLACE FUNCTION util_log.update_last_logged ()
RETURNS bigint
LANGUAGE SQL
AS $$
/**
Procedure update_last_logged updates the dt_last_logged table with the
functions, procedures, (or maybe even queries) that have been logged since the
last time that the dt_last_logged table was updated.

*/
WITH le AS (
    SELECT coalesce ( max ( tmsp_last_logged ), cast ( '1900-01-01' AS timestamp with time zone ) ) AS last_exec
        FROM util_log.dt_last_logged
),
n AS (
    SELECT dpl.obj_name,
            coalesce ( dpl.calling_obj_name, '-' ) AS calling_obj_name,
            coalesce ( dpl.username, '-' ) AS username,
            coalesce ( dpl.application_name, '-' ) AS application_name,
            min ( dpl.tmsp_exec ) AS tmsp_first_logged,
            max ( dpl.tmsp_exec ) AS tmsp_last_logged,
            count (*) AS logged_count
        FROM util_log.dt_proc_log dpl
        CROSS JOIN le
        WHERE dpl.tmsp_exec > le.last_exec
        GROUP BY dpl.obj_name,
            coalesce ( dpl.calling_obj_name, '-' ),
            coalesce ( dpl.username, '-' ),
            coalesce ( dpl.application_name, '-' )
),
upd AS (
    UPDATE util_log.dt_last_logged o
        SET tmsp_last_logged = n.tmsp_last_logged,
            logged_count = o.logged_count + n.logged_count
        FROM n
        WHERE o.obj_name = n.obj_name
            AND o.calling_obj_name = n.calling_obj_name
            AND o.username = n.username
            AND o.application_name = n.application_name
        RETURNING 1
),
ins AS (
    INSERT INTO util_log.dt_last_logged (
            tmsp_first_logged,
            tmsp_last_logged,
            logged_count,
            obj_name,
            calling_obj_name,
            username,
            application_name )
        SELECT n.tmsp_first_logged,
                n.tmsp_last_logged,
                n.logged_count,
                n.obj_name,
                n.calling_obj_name,
                n.username,
                n.application_name
            FROM n
            WHERE NOT EXISTS (
                    SELECT 1
                        FROM util_log.dt_last_logged s
                        WHERE s.obj_name = n.obj_name
                            AND s.calling_obj_name = n.calling_obj_name
                            AND s.username = n.username
                            AND s.application_name = n.application_name
                )
            RETURNING 1
)
SELECT count ( upd.*) + count ( ins.*)
    FROM upd
    CROSS JOIN ins ;

$$ ;
