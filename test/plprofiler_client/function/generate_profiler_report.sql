CREATE OR REPLACE FUNCTION plprofiler_client.generate_profiler_report (
    a_name text DEFAULT NULL,
    a_title text DEFAULT NULL,
    a_max_rank integer DEFAULT NULL )
RETURNS TABLE (
    report_html text )
LANGUAGE plpgsql
STABLE
AS $$
/**
Function generate_profiler_report generates an HTML profiler report for functions
and procedures that includes a flame-graphy thing for the most expensive functions
and procedures.

| Parameter                      | In/Out | Datatype   | Description                                        |
| ------------------------------ | ------ | ---------- | -------------------------------------------------- |
| a_name                         | in     | text       | The profiler name/label to create a coverage report for |
| a_title                        | in     | text       | The title to give the report                       |
| a_max_rank                     | in     | integer    | The number of entries to include in the flame-graphy portion based on total and/or average cost |

*/
DECLARE

    l_title text ;
    l_max_rank integer ;
    l_td_right constant text := '<td align="right">%s</td>' ;

BEGIN

    perform plprofiler_client.set_search_path () ;

    l_max_rank := coalesce ( a_max_rank, 5 ) ;

    l_title := plprofiler_client.esc_html ( coalesce (
            a_title,
            format ( 'PL Profiler Report for %s %s', a_name, to_char ( now (), ' [yyyy-mm-dd hh24:mi:ss]' ) ) ) ) ;

    RETURN QUERY
    SELECT format ( '<!doctype html>
<html>
<head>
  <title>%s</title>
', l_title ) ;

    RETURN QUERY
    SELECT '<script language="javascript">
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
' ;

    RETURN QUERY
    SELECT format ( '
  <h1>%s</h1>
', l_title ) ;

    RETURN QUERY
    SELECT '<h2>Hot Spots</h2>
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
' ;

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
        SELECT ( split_part ( c.c_stack[array_upper ( c.c_stack, 1 )], '=', 2 ) )::oid AS func_oid,
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
                CASE WHEN exec_count > 0 THEN round ( ( total_time / exec_count ), 0 ) ELSE 0 END AS average_time,
                row_number () OVER ( ORDER BY total_time DESC ) AS total_rank,
                row_number () OVER ( ORDER BY max_time DESC ) AS max_rank,
                row_number () OVER (
                    ORDER BY CASE WHEN exec_count > 0 THEN total_time / exec_count ELSE 0 END DESC ) AS average_rank
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
                CASE
                    WHEN st_b.total_time = st_m.total_time THEN '00'
                    ELSE to_hex ( 255
                            - ( 2.55
                                * round ( ( st_b.total_time::numeric / st_m.total_time / st_m.total_ratio * 100 ),
                                    2 ) )::int )
                    END AS total_flame_hex,
                CASE
                    WHEN st_b.average_time = st_m.average_time THEN '00'
                    ELSE to_hex ( 255
                            - ( 2.55 * round ( ( st_b.average_time::numeric / st_m.average_time * 100 ), 2 ) )::int )
                    END AS avg_flame_hex
            FROM st_b
            CROSS JOIN st_m
    ),
    ----------------------------------------------------------------------------
    flame AS (
        SELECT n.nspname::text AS schema_name,
                p.proname::text AS func_name,
                CASE
                    WHEN p.prokind = 'f' THEN 'Function'
                    WHEN p.prokind = 'p' THEN 'Procedure'
                    ELSE ''
                    END AS func_type,
                st_f.func_oid,
                st_f.exec_count,
                st_f.total_percent,
                st_f.total_flame_hex,
                st_f.total_time,
                st_f.avg_flame_hex,
                st_f.average_time,
                st_f.total_rank + st_f.average_rank AS st_rank
            FROM st_f
            JOIN pg_catalog.pg_proc p
                ON ( p.oid = st_f.func_oid )
            JOIN pg_catalog.pg_namespace n
                ON ( n.oid = p.pronamespace )
            WHERE ( total_rank <= l_max_rank
                    AND total_percent >= 0.5 )
                OR average_rank <= l_max_rank
    )
    SELECT concat (
                format ( '<tr valign="top"><td>%s</td>', func_type ),
                format (
                    '<td>%s</td><td>%s</td>',
                    plprofiler_client.esc_html ( schema_name ),
                    plprofiler_client.esc_html ( func_name ) ),
                format ( l_td_right, func_oid ),
                format ( l_td_right, exec_count ),
                format ( l_td_right, total_percent ),
                format ( '<td align="right" bgcolor="ff%s00">%s</td>', total_flame_hex, total_time ),
                format ( '<td align="right" bgcolor="ff%s00">%s</td></tr>', avg_flame_hex, average_time ) ) AS tbl
        FROM flame
        ORDER BY st_rank ;

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
                ( split_part ( c.c_stack[array_upper ( c.c_stack, 1 )], '=', 2 ) )::bigint AS func_oid,
                sum ( c.c_us_self ) AS total_time,
                row_number () OVER () AS rn
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
                CASE
                    WHEN proc.prokind = 'f' THEN 'Function'
                    WHEN proc.prokind = 'p' THEN 'Procedure'
                    ELSE ''
                    END AS func_type,
                min ( CASE WHEN psl.l_line_number = 0 THEN psl.l_total_time END ) AS total_time,
                min ( CASE WHEN psl.l_line_number = 0 THEN psl.l_exec_count END ) AS exec_count,
                max ( psl.l_line_number ) AS line_count,
                string_agg (
                    concat (
                        '<tr>',
                        format ( l_td_right, psl.l_line_number ),
                        format ( l_td_right, psl.l_exec_count ),
                        format ( l_td_right, psl.l_total_time ),
                        format ( l_td_right, psl.l_longest_time ),
                        '<td align="left"><code>',
                        CASE
                            WHEN psl.l_line_number = 0 THEN '-- Function Totals'
                            ELSE plprofiler_client.esc_html ( psl.l_source )
                            END,
                        '</code></td></tr>' ),
                    E'\n'
                    ORDER BY psl.l_line_number ) AS src
            FROM pl_profiler_saved_linestats psl
            JOIN ps
                ON ( ps.s_id = psl.l_s_id )
            LEFT JOIN pg_catalog.pg_proc proc
                ON ( proc.oid = psl.l_funcoid )
            GROUP BY psl.l_s_id,
                psl.l_funcoid,
                proc.prokind
    )
    SELECT concat_ws (
                E'\n',
                concat (
                    format ( '<tr id="g%s"><td>%s</td>', st_i.rn, src.func_type ),
                    format (
                        '<td>%s</td><td>%s</td>',
                        plprofiler_client.esc_html ( psf.f_schema ),
                        plprofiler_client.esc_html ( psf.f_funcname ) ),
                    format ( l_td_right, psf.f_funcoid ),
                    format ( l_td_right, src.line_count ),
                    format ( l_td_right, src.exec_count ),
                    format ( l_td_right, round ( ( st_i.total_time::numeric / st_m.total_time * 100 ), 2 ) ),
                    format ( l_td_right, st_i.total_time ),
                    format (
                        l_td_right,
                        CASE
                            WHEN coalesce ( src.exec_count, 0 ) = 0 OR coalesce ( st_i.total_time, 0 ) = 0 THEN '0'
                            ELSE ( round ( st_i.total_time::numeric / src.exec_count::numeric, 0 ) )::text
                            END
                        ),
                    format ( l_td_right, src.total_time ),
                    format (
                        l_td_right,
                        CASE
                            WHEN coalesce ( src.exec_count, 0 ) = 0 OR coalesce ( src.total_time, 0 ) = 0 THEN '0'
                            ELSE ( round ( src.total_time::numeric / src.exec_count::numeric, 0 ) )::text
                            END
                        ),
                    format (
                        '<td>(<a id="toggle_%s" href="javascript:toggle_div(''toggle_%s'', ''dtl_%s'')">show</a>)</tr>',
                        st_i.rn,
                        st_i.rn,
                        st_i.rn ) ),
                --------------------------------------------------------------------------------
                -- Function details
                '<tr><td width="5%%"></td><td colspan="11">',
                format ( '<table class="linestats" id="dtl_%s" align="left" style="display: none">', st_i.rn ),
                --------------------------------------------------------------------------------
                -- Function signature
                concat (
                    format (
                        '<tr><td colspan="5"><b><code>%s.%s%s',
                        plprofiler_client.esc_html ( psf.f_schema ),
                        plprofiler_client.esc_html ( psf.f_funcname ),
                        CASE
                            WHEN coalesce ( psf.f_funcargs, '' ) = '' THEN ' ()'
                            ELSE concat (
                                E' (<br/>&nbsp;&nbsp;&nbsp;&nbsp;',
                                replace ( psf.f_funcargs, ', ', ',<br/>&nbsp;&nbsp;&nbsp;&nbsp;' ),
                                ' )' )
                            END
                        ),
                    CASE
                        WHEN src.func_type = 'Function'
                            THEN ' returns ' || plprofiler_client.esc_html ( psf.f_funcresult )
                        ELSE ''
                        END,
                    '</code></b></td></tr>' ),
                -- End Function signature
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
                -- End Source code data
                -- End Function details
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
        ORDER BY psf.f_schema,
            src.func_type,
            psf.f_funcname,
            psf.f_funcoid ;

    RETURN QUERY
    SELECT '</tbody>
</table>
</body>
</html>
' ;

END ;
$$ ;
