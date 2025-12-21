CREATE OR REPLACE FUNCTION util_log.manage_partitions ()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, util_log
AS $$
/**
Procedure manage_partitions creates (and disposes of) table partitions
for the util_log.dt_proc_log table.

*/
DECLARE

    l_schema_name text := 'util_log' ; -- The name of the schema for the partitioned table
    l_table_name text := 'dt_proc_log' ; -- The name of the table to manage partitions for
    l_retention_days integer := 30 ; -- The number of past days to retain logs for.
    l_pre_days integer := 10 ; -- The number of future days to pre-create partitions for.
    -- The intent is to maintain a buffer so that, in the
    -- event that this function is not run for a few days,
    -- the logging functionality can continue to work.

    dt record ;

BEGIN

    -- ASSERTION: the schema name and table name of the partitioned table do not require quoting
    -- ASSERTION: there are no other partitioned tables in the schema that have a similar name
    -- ASSERTION: the table partitions reside in the same schema as the parent table

    -- NB: in the event that there are ever any partitions that are desired to be preserved
    --  beyond the retention schedule then they either need to be renamed in such fashion that
    --  breaks the naming pattern or, better yet, manually detached from the parent table

    FOR dt IN (
        WITH args AS (
            SELECT l_retention_days AS retention_days,
                    l_pre_days AS pre_days,
                    l_retention_days + l_pre_days AS total_days,
                    l_schema_name AS schema_name,
                    l_table_name AS table_name
        ),
        dates AS (
            SELECT ( current_date
                            + ( ( s.idx - args.retention_days )::text
                                || ' days'::text )::interval )::date AS partition_date
                FROM args
                CROSS JOIN (
                    SELECT idx
                        FROM generate_series ( 1, (
                                SELECT total_days
                                    FROM args ), 1 ) AS gs ( idx )
                    ) s
        ),
        new_parts AS (
            SELECT args.table_name || '_' || to_char ( dates.partition_date, 'yyyymmdd' ) AS partition_name,
                    to_char ( dates.partition_date, 'yyyy-mm-dd' ) AS partition_date
                FROM dates
                CROSS JOIN args
        ),
        cur_parts AS (
            SELECT c.relname AS partition_name
                FROM pg_catalog.pg_class c
                JOIN pg_catalog.pg_namespace n
                    ON ( n.oid = c.relnamespace )
                JOIN pg_catalog.pg_inherits i
                    ON ( c.oid = i.inhrelid )
                CROSS JOIN args
                WHERE n.nspname = args.schema_name
                    AND c.relname::text ~ ( args.table_name || '_.+' )::text
        )
        SELECT args.schema_name,
                args.table_name,
                cur_parts.partition_name AS current_partition,
                new_parts.partition_name AS new_partition,
                new_parts.partition_date
            FROM cur_parts
            FULL JOIN new_parts
                ON ( cur_parts.partition_name = new_parts.partition_name )
            CROSS JOIN args
            ORDER BY coalesce ( cur_parts.partition_name, new_parts.partition_name ) ) LOOP

        IF dt.current_partition IS NULL THEN

            EXECUTE format (
                    'CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM ( %L::date ) TO ( ( %L::date + ''1 day''::interval )::date )',
                    dt.schema_name,
                    dt.new_partition,
                    dt.schema_name,
                    dt.table_name,
                    dt.partition_date,
                    dt.partition_date ) ;

        ELSIF dt.new_partition IS NULL THEN

            EXECUTE format (
                    'ALTER TABLE %I.%I DETACH PARTITION %I.%I',
                    dt.schema_name,
                    dt.table_name,
                    dt.schema_name,
                    dt.current_partition ) ;

            EXECUTE format ( 'DROP TABLE %I.%I', dt.schema_name, dt.current_partition ) ;

        END IF ;

    END LOOP ;

END ;
$$ ;

SELECT true
    FROM util_log.manage_partitions () ;
