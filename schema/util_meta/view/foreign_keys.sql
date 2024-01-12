CREATE OR REPLACE VIEW util_meta.foreign_keys
AS
WITH referential_constraints AS (
    SELECT ncon.nspname::text AS constraint_schema,
            con.conname::text AS constraint_name,
            con.oid,
            npkc.nspname::text AS unique_constraint_schema,
            pkc.conname::text AS unique_constraint_name,
            mr.label AS match_option,
            ur.label AS update_rule,
            dr.label AS delete_rule
        FROM pg_catalog.pg_constraint con
        JOIN pg_catalog.pg_namespace ncon
            ON ( ncon.oid = con.connamespace )
        JOIN pg_catalog.pg_class c
            ON ( con.conrelid = c.oid
                AND con.contype = 'f' )
        LEFT JOIN util_meta.conftypes mr
            ON ( mr.conftype = con.confmatchtype::text )
        LEFT JOIN util_meta.conftypes ur
            ON ( ur.conftype = con.confupdtype::text )
        LEFT JOIN util_meta.conftypes dr
            ON ( dr.conftype = con.confdeltype::text )
        LEFT JOIN pg_catalog.pg_depend d1
            ON ( d1.objid = con.oid
                AND d1.classid = ( 'pg_constraint'::regclass )::oid
                AND d1.refclassid = ( 'pg_class'::regclass )::oid
                AND d1.refobjsubid = 0 )
        LEFT JOIN pg_catalog.pg_depend d2
            ON ( d2.refclassid = ( 'pg_constraint'::regclass )::oid
                AND d2.classid = ( 'pg_class'::regclass )::oid
                AND d2.objid = d1.refobjid
                AND d2.objsubid = 0
                AND d2.deptype = 'i' )
        LEFT JOIN pg_catalog.pg_constraint pkc
            ON ( pkc.oid = d2.refobjid
                AND pkc.contype IN ( 'p', 'u' )
                AND pkc.conrelid = con.confrelid )
        LEFT JOIN pg_catalog.pg_namespace npkc
            ON ( pkc.connamespace = npkc.oid
                AND npkc.nspname <> 'information_schema'
                AND npkc.nspname !~ '^pg_' )
        WHERE ncon.nspname <> 'information_schema'
            AND ncon.nspname !~ '^pg_'
),
table_constraints AS (
    SELECT nc.nspname::text AS constraint_schema,
            c.conname::text AS constraint_name,
            nr.nspname::text AS schema_name,
            r.relname::text AS object_name,
            contypes.label AS constraint_type,
            c.condeferrable AS is_deferrable,
            c.condeferred AS initially_deferred
        FROM pg_catalog.pg_constraint c
        JOIN pg_catalog.pg_namespace nc
            ON ( nc.oid = c.connamespace )
        JOIN pg_catalog.pg_class r
            ON ( c.conrelid = r.oid )
        JOIN pg_catalog.pg_namespace nr
            ON ( nr.oid = r.relnamespace )
        JOIN util_meta.objects o
            ON ( o.schema_name = nr.nspname
                AND o.object_name = r.relname )
        JOIN util_meta.contypes
            ON ( contypes.contype = c.contype::text )
        WHERE r.relkind IN ( 'r', 'p' )
            AND NOT pg_is_other_temp_schema ( nr.oid )
            AND nc.nspname <> 'information_schema'
            AND nc.nspname !~ '^pg_'
            AND nr.nspname <> 'information_schema'
            AND nr.nspname !~ '^pg_'
)
SELECT tab.schema_name AS schema_name,
        tab.object_name AS table_name,
        concat_ws ( '.', tab.schema_name, tab.object_name ) AS full_table_name,
        split_part ( split_part ( pg_catalog.pg_get_constraintdef ( con.oid, true ), '(', 2 ), ')', 1 ) AS column_names,
        tab.constraint_name AS constraint_name,
        rtab.schema_name AS ref_schema_name,
        rtab.object_name AS ref_table_name,
        concat_ws ( '.', rtab.schema_name, rtab.object_name ) AS ref_full_table_name,
        split_part ( split_part ( pg_catalog.pg_get_constraintdef ( con.oid, true ), '(', 3 ), ')', 1 ) AS ref_column_names,
        rtab.constraint_name AS ref_constraint_name,
        con.match_option,
        con.update_rule,
        con.delete_rule
    FROM referential_constraints con
    JOIN table_constraints tab
        ON ( con.constraint_schema = tab.constraint_schema
            AND con.constraint_name = tab.constraint_name )
    JOIN table_constraints rtab
        ON ( rtab.constraint_schema = con.unique_constraint_schema
            AND rtab.constraint_name = con.unique_constraint_name ) ;

COMMENT ON VIEW util_meta.foreign_keys IS 'Metadata for the application database foreign key relationships' ;

COMMENT ON COLUMN util_meta.foreign_keys.schema_name IS 'The name of the schema that contains the child table.' ;
COMMENT ON COLUMN util_meta.foreign_keys.table_name IS 'The name of the child table.' ;
COMMENT ON COLUMN util_meta.foreign_keys.full_table_name IS 'The full name of the child table.' ;
COMMENT ON COLUMN util_meta.foreign_keys.column_names IS 'The comma-separated list of columns in the child table that participate in the relationship.' ;
COMMENT ON COLUMN util_meta.foreign_keys.constraint_name IS 'The name of the foreign key constraint.' ;
COMMENT ON COLUMN util_meta.foreign_keys.ref_schema_name IS 'The name of the table that contains the parent table.' ;
COMMENT ON COLUMN util_meta.foreign_keys.ref_table_name IS 'The name of the parent table.' ;
COMMENT ON COLUMN util_meta.foreign_keys.ref_full_table_name IS 'The full name of the parent table.' ;
COMMENT ON COLUMN util_meta.foreign_keys.ref_column_names IS 'The comma-separated list of columns in the parent table primary key.' ;
COMMENT ON COLUMN util_meta.foreign_keys.ref_constraint_name IS 'The name of the primary key' ;
COMMENT ON COLUMN util_meta.foreign_keys.match_option IS 'The match rule' ;
COMMENT ON COLUMN util_meta.foreign_keys.update_rule IS 'The update rule' ;
COMMENT ON COLUMN util_meta.foreign_keys.delete_rule IS 'The delete rule' ;
