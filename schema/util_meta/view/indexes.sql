CREATE OR REPLACE VIEW util_meta.indexes
AS
WITH indexes AS (
    SELECT nr.nspname::text AS index_schema,
            c2.relname::text AS index_name,
            nr.nspname::text AS table_schema,
            c.relname::text AS table_name,
            idx.indisunique,
            idx.indisprimary,
            idx.indisvalid,
            regexp_split_to_array (
                split_part ( pg_catalog.pg_get_indexdef ( idx.indexrelid, 0, true ), 'INDEX', 2 ),
                '[\(\)]' ) AS def
        FROM pg_catalog.pg_index idx
        INNER JOIN pg_catalog.pg_class c
            ON ( c.oid = idx.indrelid )
        INNER JOIN pg_catalog.pg_class c2
            ON ( c2.oid = idx.indexrelid )
        JOIN util_meta.schemas
            ON ( schemas.schema_oid IN ( c.relnamespace, c2.relnamespace ) )
        INNER JOIN pg_namespace nr
            ON ( nr.oid = c.relnamespace )
        WHERE idx.indislive
            AND nr.nspname <> 'information_schema'
            AND nr.nspname !~ '^pg_'
)
SELECT index_schema,
        index_name,
        concat_ws ( '.', index_schema, index_name ) AS full_index_name,
        table_schema,
        table_name,
        concat_ws ( '.', table_schema, table_name ) AS full_table_name,
        indisunique AS is_unique,
        indisprimary AS is_primary,
        indisvalid AS is_valid,
        split_part ( def[1], ' ', 6 ) AS index_type,
        def[2] AS column_names
    FROM indexes ;

COMMENT ON VIEW util_meta.indexes IS 'Metadata for the application database indexes' ;

COMMENT ON COLUMN util_meta.indexes.index_schema IS 'The schema of the index.' ;
COMMENT ON COLUMN util_meta.indexes.index_name IS 'The name of the index.' ;
COMMENT ON COLUMN util_meta.indexes.full_index_name IS 'The full name of the index.' ;
COMMENT ON COLUMN util_meta.indexes.table_schema IS 'The schema of the indexed table.' ;
COMMENT ON COLUMN util_meta.indexes.table_name IS 'The name of the indexed table.' ;
COMMENT ON COLUMN util_meta.indexes.full_table_name IS 'The full name of the indexed table.' ;
COMMENT ON COLUMN util_meta.indexes.is_unique IS 'Indicates if the index is unique.' ;
COMMENT ON COLUMN util_meta.indexes.is_primary IS 'Indicates if the index is for a primary key.' ;
COMMENT ON COLUMN util_meta.indexes.is_valid IS 'Indicates if the index is valid.' ;
COMMENT ON COLUMN util_meta.indexes.index_type IS 'The type of index.' ;
COMMENT ON COLUMN util_meta.indexes.column_names IS 'The indexed columns.' ;
