CREATE OR REPLACE VIEW util_meta.foreign_keys
AS
WITH referential_constraints AS (
    SELECT tsc.nspname::text AS schema_name,
            tbl.relname::text AS table_name,
            con.conname::text AS constraint_name,
            rcon.relname::text AS ref_constraint_name,
            mr.label AS match_option,
            ur.label AS update_rule,
            dr.label AS delete_rule,
            regexp_split_to_array ( pg_catalog.pg_get_constraintdef ( con.oid ), '[ \(\)]' ) AS def
        FROM pg_catalog.pg_constraint con
        JOIN pg_catalog.pg_class tbl
            ON ( tbl.oid = con.conrelid )
        JOIN pg_catalog.pg_namespace tsc
            ON ( tsc.oid = tbl.relnamespace )
        JOIN pg_catalog.pg_class rcon
            ON ( rcon.oid = con.conindid )
        LEFT JOIN util_meta.conftypes mr
            ON ( mr.conftype = con.confmatchtype::text )
        LEFT JOIN util_meta.conftypes ur
            ON ( ur.conftype = con.confupdtype::text )
        LEFT JOIN util_meta.conftypes dr
            ON ( dr.conftype = con.confdeltype::text )
        WHERE con.contype = 'f'
            AND tsc.nspname <> 'information_schema'
            AND tsc.nspname !~ '^pg_'
)
SELECT schema_name,
        table_name,
        concat_ws ( '.', schema_name, table_name ) AS full_table_name,
        def[4] AS column_names,
        constraint_name,
        split_part ( def[7], '.', 1 ) AS ref_schema_name,
        split_part ( def[7], '.', 2 ) AS ref_table_name,
        def[7] AS ref_full_table_name,
        def[8] AS ref_column_names,
        ref_constraint_name,
        match_option,
        update_rule,
        delete_rule
    FROM referential_constraints ;

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
COMMENT ON COLUMN util_meta.foreign_keys.ref_constraint_name IS 'The name of the primary key/unique constraint' ;
COMMENT ON COLUMN util_meta.foreign_keys.match_option IS 'The match rule' ;
COMMENT ON COLUMN util_meta.foreign_keys.update_rule IS 'The update rule' ;
COMMENT ON COLUMN util_meta.foreign_keys.delete_rule IS 'The delete rule' ;
