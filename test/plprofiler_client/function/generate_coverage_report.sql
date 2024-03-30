
CREATE OR REPLACE FUNCTION plprofiler_client.generate_coverage_report (
    a_name text DEFAULT NULL,
    a_title text DEFAULT NULL )
RETURNS TABLE (
    report_html text )
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $function$
DECLARE

    l_title text ;

BEGIN

    PERFORM plprofiler_client.set_search_path ( ) ;

    IF a_title IS NOT NULL THEN
        l_title := a_title ;
    ELSE
        l_title := 'PL Coverage Report for ' || a_name || to_char ( now(), ' [yyyy-mm-dd hh24:mi:ss]' ) ;
    END IF ;

    RETURN QUERY
    SELECT '<html>
<head>
  <title>' || l_title || '</title>
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
        background-color: hsl(240, 67%, 94%);
    }
    table.rptData tr:nth-child(even) {
        background-color: hsl(0, 0%, 85%);
    }
    </style>

</head>
<body>

<h1>' || l_title || '</h1>

<h2>Summary</h2>
<table class="rptData" id="rptSum" width="95%">
<thead>
<tr>
    <th>Schema</th>
    <th>Total Count</th>
    <th>PL/pgSQL</th>
    <th>PL/pgSQL Percent</th>
    <th>SQL</th>
    <th>SQL Percent</th>
    <th>Other</th>
    <th>Other Percent</th>
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
    sf AS (
        SELECT f.f_s_id,
                f.f_funcoid
            FROM ps
            JOIN pl_profiler_saved_functions f
                ON ( f.f_s_id = ps.s_id )
            GROUP BY f.f_s_id,
                f.f_funcoid
    ),
    x AS (
        SELECT obj.schema_name,
                CASE
                    WHEN obj.procedure_language = 'plpgsql' AND sf.f_s_id IS NOT NULL THEN 1
                    ELSE 0
                    END AS p_exec,
                CASE
                    WHEN obj.procedure_language = 'plpgsql' AND sf.f_s_id IS NULL THEN 1
                    ELSE 0
                    END AS p_nexec,
                CASE
                    WHEN obj.procedure_language = 'sql' AND sf.f_s_id IS NOT NULL THEN 1
                    ELSE 0
                    END AS s_exec,
                CASE
                    WHEN obj.procedure_language = 'sql' AND sf.f_s_id IS NULL THEN 1
                    ELSE 0
                    END AS s_nexec,
                CASE
                    WHEN obj.procedure_language NOT IN ( 'plpgsql', 'sql' ) AND sf.f_s_id IS NOT NULL THEN 1
                    ELSE 0
                    END AS o_exec,
                CASE
                    WHEN obj.procedure_language NOT IN ( 'plpgsql', 'sql' ) AND sf.f_s_id IS NULL THEN 1
                    ELSE 0
                    END AS o_nexec
            FROM util_meta.objects obj
            LEFT JOIN pg_catalog.pg_trigger
                ON ( pg_trigger.tgfoid = obj.object_oid )
            LEFT JOIN sf
                ON ( sf.f_funcoid = obj.object_oid )
            WHERE obj.object_type IN ( 'function', 'procedure' )
    ),
    y AS (
        SELECT schema_name,
                count (*) AS total_count,
                sum ( p_exec + p_nexec ) AS p_count,
                sum ( p_exec ) AS p_exec,
                sum ( p_nexec ) AS p_nexec,
                sum ( s_exec + s_nexec ) AS s_count,
                sum ( s_exec ) AS s_exec,
                sum ( s_nexec ) AS s_nexec,
                sum ( o_exec + o_nexec ) AS o_count,
                sum ( o_exec ) AS o_exec,
                sum ( o_nexec ) AS o_nexec
            FROM x
            GROUP BY schema_name
    ),
    z AS (
        SELECT schema_name,
                total_count,
                concat_ws ( ' / ', p_exec::text, p_count::text ) AS plpgsql_ratio,
                CASE
                    WHEN p_count > 0 THEN floor ( p_exec::numeric / p_count * 100 )::text
                    ELSE '-'::text
                    END AS plpgsql_pct_exec,
                concat_ws ( ' / ', s_exec::text, s_count::text ) AS sql_ratio,
                CASE
                    WHEN s_count > 0 THEN floor ( s_exec::numeric / s_count * 100 )::text
                    ELSE '-'::text
                    END AS sql_pct_exec,
                concat_ws ( ' / ', o_exec::text, o_count::text ) AS other_ratio,
                CASE
                    WHEN o_count > 0 THEN floor ( o_exec::numeric / o_count * 100 )::text
                    ELSE '-'::text
                    END AS other_pct_exec
            FROM y
            ORDER BY schema_name
    )
    SELECT concat (
            '<tr valign="top">',
            '<td>', z.schema_name, '</td>',
            '<td align="right">', z.total_count, '</td>',
            '<td align="center">', z.plpgsql_ratio, '</td>',
            '<td align="right">', z.plpgsql_pct_exec, '</td>',
            '<td align="center">', z.sql_ratio, '</td>',
            '<td align="right">', z.sql_pct_exec, '</td>',
            '<td align="center">', z.other_ratio, '</td>',
            '<td align="right">', z.other_pct_exec, '</td>',
            '</tr>' ) AS tbl
        FROM z
        ORDER BY z.schema_name ;


    RETURN QUERY
    SELECT '</tbody>
</table>

<h2>Details</h2>
<table class="rptData" id="rptDtl" width="95%">
<thead>
<tr>
    <th>Type</th>
    <th>Schema</th>
    <th>Name</th>
    <th>OID</th>
    <th>Return Type</th>
    <th>Language</th>
    <th>Was Executed</th>
    <th>Is Unused Trigger</th>
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
    sf AS (
        SELECT f.f_s_id,
                f.f_funcoid
            FROM ps
            JOIN plprofiler.pl_profiler_saved_functions f
                ON ( f.f_s_id = ps.s_id )
            GROUP BY f.f_s_id,
                f.f_funcoid
    ),
    x AS (
        SELECT DISTINCT initcap ( obj.object_type ) AS object_type,
                obj.schema_name,
                obj.object_name,
                obj.object_oid,
                CASE
                    WHEN obj.object_type = 'function' THEN split_part ( obj.result_data_type, '(', 1 )
                    ELSE ''
                    END AS return_type,
                obj.procedure_language,
                CASE
                    WHEN sf.f_s_id IS NOT NULL THEN 'Y'
                    ELSE 'N'
                    END AS was_executed,
                CASE
                    WHEN obj.result_data_type = 'trigger' AND pg_trigger.tgfoid IS NULL THEN 'Y'
                    WHEN obj.result_data_type = 'trigger' THEN 'N'
                    ELSE '-'
                    END AS is_unused_trigger
            FROM util_meta.objects obj
            LEFT JOIN pg_catalog.pg_trigger
                ON ( pg_trigger.tgfoid = obj.object_oid )
            LEFT JOIN sf
                ON ( sf.f_funcoid = obj.object_oid )
            WHERE obj.object_type IN ( 'function', 'procedure' )
    )
    SELECT concat (
            '<tr valign="top">',
            '<td>', x.object_type, '</td>',
            '<td>', x.schema_name, '</td>',
            '<td>', x.object_name, '</td>',
            '<td>', x.object_oid, '</td>',
            '<td>', x.return_type, '</td>',
            '<td>', x.procedure_language, '</td>',
            '<td align="center">', x.was_executed, '</td>',
            '<td align="center">', x.is_unused_trigger, '</td>',
            '</tr>' ) AS tbl
        FROM x
        ORDER BY x.schema_name,
            x.object_name,
            x.object_oid ;

    RETURN QUERY
    SELECT '</tbody>
</table>
</body>
</html>
' ;

END ;
$function$ ;
