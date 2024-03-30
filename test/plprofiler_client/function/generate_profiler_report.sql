
CREATE OR REPLACE FUNCTION plprofiler_client.generate_profiler_report (
    a_name text DEFAULT NULL,
    a_title text DEFAULT NULL,
    a_max_rank integer DEFAULT NULL )
RETURNS TABLE (
    report_html text )
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
DECLARE

    l_title text ;
    l_max_rank integer ;

BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;

    l_max_rank := coalesce ( a_max_rank, 5 ) ;

    IF a_title IS NOT NULL THEN
        l_title := a_title ;
    ELSE
        l_title := 'PL Profiler Report for ' || a_name || to_char ( now(), ' [yyyy-mm-dd hh24:mi:ss]' ) ;
    END IF ;

    RETURN QUERY
    SELECT '<html>
<head>
  <title>' || l_title || '</title>
  <script language="javascript">
    // ----
    // toggle_div()
    //
    //  JS function to toggle one of the functions to show/block.
    // ----
    function toggle_div(tog_id, dtl_id) {
        var tog_elem = document.getElementById(tog_id);
        var dtl_elem = document.getElementById(dtl_id);
        if (dtl_elem.style.display == "block") {
            dtl_elem.style.display = "none";
            tog_elem.innerHTML = "show";
        } else {
            dtl_elem.style.display = "block";
            tog_elem.innerHTML = "hide";
        }
    }
    </script>

    <style>
    body {
        background-color: hsl(0, 0%, 95%);;
        font-family: verdana,helvetica,sans-serif;
        margin: 5px;
        padding: 0;
    }
    table.rptData  {
        margin-left: auto;
        margin-right: auto;
    }
    table.rptData thead tr th {
        background-color: hsl(0, 0%, 85%);
        border-bottom: 2px solid hsl(0, 0%, 50%);
        border-right: 2px solid hsl(0, 0%, 50%);
        color: hsl(213, 48%, 38%);
        padding-left: 4px;
        padding-right: 4px;
    }

    table.rptData td {
        padding-left: 10px;
        padding-right: 10px;
    }
    table.rptData tr:nth-child(odd) {
        background-color: hsl(0, 0%, 90%);
    }
    table.rptData tr:nth-child(even) {
        background-color: hsl(240, 67%, 94%);
    }

    code {
        padding-left: 10px;
        padding-right: 10px;
    }
    table.linestats td {
        padding-left: 10px;
        padding-right: 10px;
    }
    table.linestats tr:nth-child(odd) {
        background-color: hsl(240, 67%, 94%);
    }
    table.linestats tr:nth-child(even) {
        background-color: hsl(0, 0%, 85%);
    }
    </style>

</head>
<body>

<h1>' || l_title || '</h1>

<h2>Hot Spots</h2>
<table class="rptData" id="rptHotSpots" width="95%">
<thead>
<tr>
    <th align="left" rowspan="2">Type</th>
    <th align="left" rowspan="2">Schema</th>
    <th align="left" rowspan="2">Name</th>
    <th align="right" rowspan="2">OID</th>
    <th align="right" rowspan="2">Exec Count</th>
    <th align="center" colspan="3">Self Time</th>
</tr>
<tr>
    <th align="right">Total (&percnt;)</th>
    <th align="right">Total (µs)</th>
    <th align="right">Average (µs)</th>
</tr>
</thead>
<tbody>
';

    RETURN QUERY
    WITH ps AS (
        SELECT s_id,
                s_name,
                s_options,
                s_callgraph_overflow,
                s_functions_overflow,
                s_lines_overflow
            FROM pl_profiler_saved
            WHERE s_name = a_name
    ),
    ----------------------------------------------------------------------------
    -- Self-Time (Call Graph)
    st_i AS (
        SELECT ( split_part ( c.c_stack [ array_upper ( c.c_stack, 1 ) ], '=', 2 ) )::oid AS func_oid,
                sum ( c.c_call_count ) AS exec_count,
                sum ( c.c_us_self ) AS total_time,
                max ( c.c_us_self ) AS max_time
            FROM ps
            JOIN pl_profiler_saved_callgraph c
                ON ( c.c_s_id = ps.s_id )
            GROUP BY func_oid
    ),
    st_b AS (
        SELECT func_oid,
                exec_count,
                total_time,
                max_time,
                CASE
                    WHEN exec_count > 0 THEN round ( ( total_time / exec_count ), 0 )
                    ELSE 0
                    END AS average_time,
                row_number () OVER ( ORDER BY total_time desc ) AS total_rank,
                row_number () OVER ( ORDER BY max_time desc ) AS max_rank,
                row_number () OVER ( ORDER BY CASE WHEN exec_count > 0 THEN total_time / exec_count ELSE 0 END desc ) AS average_rank
            FROM st_i
            WHERE coalesce ( exec_count, 0 ) > 0
    ),
    st_m AS (
        SELECT max ( total_time::numeric ) / sum ( total_time ) AS total_ratio,
                sum ( total_time ) AS total_time,
                max ( max_time ) AS max_time,
                max ( average_time ) AS average_time
            FROM st_b
    ),
    st_f AS (
        SELECT st_b.func_oid,
                st_b.exec_count,
                round ( ( st_b.total_time::numeric / st_m.total_time * 100 ), 2 ) AS total_percent,
                st_b.total_time,
                st_b.average_time,
                st_b.total_rank,
                st_b.average_rank,
                'ff' ||
                case when st_b.total_time = st_m.total_time then '00'
                    else to_hex ( 255 - ( 2.55 * round ( ( st_b.total_time::numeric / st_m.total_time / st_m.total_ratio * 100 ), 2 ) )::int ) end || '00' AS total_flame_color,
                'ff' ||
                case when st_b.average_time = st_m.average_time then '00'
                    else to_hex ( 255 - ( 2.55 * round ( ( st_b.average_time::numeric / st_m.average_time * 100 ), 2 ) )::int ) end || '00' AS avg_flame_color
            FROM st_b
            CROSS JOIN st_m
    ),
    ----------------------------------------------------------------------------
    flame AS (
        SELECT st_f.func_oid,
                st_f.exec_count,
                concat (
                    '<td align="right">', st_f.total_percent, '</td>',
                    '<td align="right" bgcolor="' || st_f.total_flame_color || '">', st_f.total_time, '</td>',
                    '<td align="right" bgcolor="' || st_f.avg_flame_color || '">', st_f.average_time, '</td>'
                    ) AS st_flame,
                st_f.total_rank + st_f.average_rank AS st_rank
            FROM st_f
            WHERE ( total_rank <= l_max_rank
                    AND total_percent >= 0.5 )
                OR average_rank <= l_max_rank
    )
    SELECT concat (
            '<tr valign="top">',
            CASE
                WHEN p.prokind = 'f' THEN '<td>Function</td>'
                WHEN p.prokind = 'p' THEN '<td>Procedure</td>'
                ELSE '<td></td>'
                END,
            '<td>', n.nspname::text, '</td>',
            '<td>', p.proname::text, '</td>',
            '<td align="right">', p.oid::text, '</td>',
            '<td align="right">', flame.exec_count, '</td>',
            flame.st_flame,
            '</tr>' ) AS tbl
        FROM flame
        JOIN pg_catalog.pg_proc p
            ON ( p.oid = flame.func_oid )
        JOIN pg_catalog.pg_namespace n
            ON ( n.oid = p.pronamespace )
        ORDER BY flame.st_rank ;

    RETURN QUERY
    SELECT '</tbody>
</table>

<h2>Details</h2>
<table class="rptData" id="rptDtl" width="95%">
<thead>
<tr>
    <th align="left" rowspan="2">Type</th>
    <th align="left" rowspan="2">Schema</th>
    <th align="left" rowspan="2">Name</th>
    <th align="right" rowspan="2">OID</th>
    <th align="right" rowspan="2">Line Count</th>
    <th align="right" rowspan="2">Exec Count</th>
    <th align="center" colspan="3">Self Time</th>
    <th align="center" colspan="2">Total Time</th>
    <th rowspan="2">Details</th>
</tr>
<tr>
    <th align="right">Total (&percnt;)</th>
    <th align="right">Total (µs)</th>
    <th align="right">Average (µs)</th>
    <th align="right">Total (µs)</th>
    <th align="right">Average (µs)</th>
</tr>
</thead>
<tbody>' ;

    RETURN QUERY
    WITH ps AS (
        SELECT s_id,
                s_name,
                s_options,
                s_callgraph_overflow,
                s_functions_overflow,
                s_lines_overflow
            FROM pl_profiler_saved
            WHERE s_name = a_name
    ),
    st_i AS (
        SELECT c.c_s_id,
                ( split_part ( c.c_stack [ array_upper ( c.c_stack, 1 ) ], '=', 2 ) )::bigint AS func_oid,
                sum ( c.c_us_self ) AS total_time,
                row_number () over () AS rn
            FROM ps
            JOIN pl_profiler_saved_callgraph c
                ON ( c.c_s_id = ps.s_id )
            GROUP BY c.c_s_id,
                    func_oid
    ),
    st_m AS (
        SELECT sum ( total_time ) AS total_time
            FROM st_i
    ),
    src AS (
        SELECT psl.l_s_id,
                psl.l_funcoid,
                min ( CASE WHEN psl.l_line_number = 0 THEN psl.l_total_time END ) AS total_time,
                min ( CASE WHEN psl.l_line_number = 0 THEN psl.l_exec_count END ) AS exec_count,
                --max ( CASE WHEN psl.l_line_number = 0 THEN psl.l_longest_time END ) AS max_time,
                max ( psl.l_line_number ) AS line_count,
                string_agg ( concat (
                    '<tr>',
                    '<td align="right">', psl.l_line_number::text, '</td>',
                    '<td align="right">', psl.l_exec_count::text, '</td>',
                    '<td align="right">', psl.l_total_time::text, '</td>',
                    '<td align="right">', psl.l_longest_time::text, '</td>',
                    '<td align="left"><code>',
                    CASE
                        WHEN psl.l_line_number = 0 THEN '-- Function Totals'
                        ELSE
                            replace (
                                replace (
                                    replace (
                                        replace (
                                            replace (
                                                replace (
                                                    replace ( psl.l_source, '&', '&amp;' ),
                                                    '>', '&gt;' ),
                                                '<', '&lt;' ),
                                            '"', '&quot;' ),
                                        '''', '&apos;' ),
                                    ' ', '&nbsp;' ),
                                E'\t', repeat ( '&nbsp;', 4 ) )
                        END,
                    '</code></td>',
                    '</tr>'
                    ), E'\n' ORDER BY psl.l_line_number ) AS src
            FROM pl_profiler_saved_linestats psl
            JOIN ps
                ON ( ps.s_id = psl.l_s_id )
            GROUP BY psl.l_s_id,
                psl.l_funcoid
    )
    SELECT concat_ws ( E'\n',
                concat (
                    '<tr id="g', st_i.rn::text, '">',
                    '<td>',
                    CASE
                        WHEN proc.prokind = 'f' THEN 'Function'
                        WHEN proc.prokind = 'p' THEN 'Procedure'
                        END,
                    '</td>',
                    '<td>', psf.f_schema, '</td>',
                    '<td>', psf.f_funcname, '</td>',
                    '<td align="right">', psf.f_funcoid::text, '</td>',
                    '<td align="right">', src.line_count::text, '</td>',
                    '<td align="right">', src.exec_count::text, '</td>',
                    '<td align="right">', round ( ( st_i.total_time::numeric / st_m.total_time * 100 ), 2 ), '</td>',
                    '<td align="right">', st_i.total_time::text, '</td>',
                    '<td align="right">',
                        CASE
                            WHEN coalesce ( src.exec_count, 0 ) = 0 OR coalesce ( st_i.total_time, 0 ) = 0 THEN '0'
                            ELSE ( round ( st_i.total_time::numeric / src.exec_count::numeric, 0 ) )::text
                            END,
                        '</td>',
                    '<td align="right">', src.total_time::text, '</td>',
                    '<td align="right">',
                        CASE
                            WHEN coalesce ( src.exec_count, 0 ) = 0 OR coalesce ( src.total_time, 0 ) = 0 THEN '0'
                            ELSE ( round ( src.total_time::numeric / src.exec_count::numeric, 0 ) )::text
                            END,
                        '</td>',
                    '<td>',
                    '(<a id="toggle_', st_i.rn::text, '" href="javascript:toggle_div(''toggle_', st_i.rn::text, ''', ''dtl_', st_i.rn::text, ''')">show</a>)',
                    '</tr>' ),
                --------------------------------------------------------------------------------
                -- Function details
                concat (
                    '<tr>',
                    '<td colspan="11">',
                    '<table class="linestats" id="dtl_', st_i.rn::text, '" align="right" style="display: none">' ),
                --------------------------------------------------------------------------------
                -- Function signature
                concat (
                    '<tr>',
                    '<td colspan="5"><b><code>',
                    psf.f_schema,
                    '.',
                    psf.f_funcname,
                    CASE
                        WHEN coalesce ( psf.f_funcargs, '' ) = '' THEN ' ()'
                        ELSE concat (
                            E' (<br/>&nbsp;&nbsp;&nbsp;&nbsp;',
                            replace ( psf.f_funcargs, ', ', ',<br/>&nbsp;&nbsp;&nbsp;&nbsp;'),
                            ' )' )
                        END,
                    CASE
                        WHEN proc.prokind = 'f' THEN ' returns ' || psf.f_funcresult
                        ELSE ''
                        END,
                    '</code></b></td>',
                    '</tr>' ),
                -- /Function signature
                --------------------------------------------------------------------------------
                -- Source code data
                concat (
                    '<tr>',
                    '<th>Line</th>',
                    '<th>Exec<br>count</th>',
                    '<th>Total<br>time (µs)</th>',
                    '<th>Longest<br>time (µs)</th>',
                    '<th>Source code</th>',
                    '</tr>' ),
                src.src,
                '</table>',
                '</td>',
                '</tr>'
                -- /Source code data
                -- /Function details
                --------------------------------------------------------------------------------
                ) AS tbl
        FROM ps
        JOIN st_i
            ON ( st_i.c_s_id = ps.s_id )
        CROSS JOIN st_m
        JOIN pl_profiler_saved_functions psf
            ON ( psf.f_s_id = st_i.c_s_id
                AND psf.f_funcoid = st_i.func_oid )
        JOIN src
            ON ( psf.f_funcoid = src.l_funcoid
                AND psf.f_s_id = src.l_s_id )
        LEFT JOIN pg_catalog.pg_proc proc
            ON ( proc.oid = psf.f_funcoid )
        ORDER BY psf.f_schema,
            proc.prokind,
            psf.f_funcname,
            psf.f_funcoid ;

    RETURN QUERY
    SELECT '</tbody>
</table>
</body>
</html>
' ;

END ;
$function$ ;
