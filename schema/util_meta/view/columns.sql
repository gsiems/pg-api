CREATE OR REPLACE VIEW util_meta.columns
AS
WITH columns AS (
    SELECT o.schema_oid,
            o.schema_name,
            o.object_oid,
            o.object_name,
            o.object_oid::bigint * 10000::bigint + a.attnum::bigint AS column_id,
            a.attname AS column_name,
            a.attnum::integer AS ordinal_position,
            pg_catalog.format_type ( a.atttypid, a.atttypmod ) AS data_type,
            CASE
                WHEN a.attnotnull THEN false
                ELSE true
                END AS is_nullable,
            pg_catalog.pg_get_expr ( ad.adbin, ad.adrelid ) AS column_default,
            CASE
                WHEN t.typtype = 'd' THEN t.typname
                END AS domain_name,
            pg_catalog.col_description ( a.attrelid, a.attnum ) AS comments
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_attribute a
            ON ( c.oid = a.attrelid
                AND a.attnum > 0
                AND NOT a.attisdropped )
        LEFT JOIN pg_catalog.pg_attrdef ad
            ON ( a.attrelid = ad.adrelid
                AND a.attnum = ad.adnum )
        JOIN pg_catalog.pg_type t
            ON ( a.atttypid = t.oid )
        JOIN pg_catalog.pg_namespace nt
            ON ( t.typnamespace = nt.oid )
        JOIN util_meta.objects o
            ON ( o.schema_oid = c.relnamespace
                AND o.object_name = c.relname::text )
        WHERE a.attnum > 0
            AND NOT a.attisdropped
            AND c.relkind IN ( 'f', 'm', 'p', 'r', 'v' )
),
primary_keys AS (
    SELECT schemas.schema_name,
            r.relname::text AS object_name,
            c.conname::text AS constraint_name,
            split_part ( split_part ( pg_get_constraintdef ( c.oid ), '(', 2 ), ')', 1 ) AS column_names
        FROM pg_catalog.pg_class r
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = r.relnamespace )
        JOIN pg_catalog.pg_constraint c
            ON ( c.conrelid = r.oid )
        WHERE r.relkind = 'r'
            AND c.contype = 'p'
),
pk_columns AS (
    SELECT schema_name,
            object_name,
            constraint_name,
            trim ( unnest ( string_to_array ( column_names, ',' ) ) ) AS column_name
        FROM primary_keys
),
natural_keys AS (
    SELECT schemas.schema_name,
            r.relname::text AS object_name,
            c.conname::text AS constraint_name,
            split_part ( split_part ( pg_get_constraintdef ( c.oid ), '(', 2 ), ')', 1 ) AS column_names
        FROM pg_catalog.pg_class r
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = r.relnamespace )
        INNER JOIN pg_catalog.pg_constraint c
            ON ( c.conrelid = r.oid )
        INNER JOIN pg_catalog.pg_namespace nc
            ON ( nc.oid = c.connamespace )
        WHERE r.relkind = 'r'
            AND c.contype = 'u'
            -- ASSERTION: natural keys will have a unique constraint and the name of the
            -- primary natural key (if there are multiple) will end with "_nk"
            AND c.conname::text = r.relname::text || '_nk'
),
nk_columns AS (
    SELECT schema_name,
            object_name,
            constraint_name,
            trim ( unnest ( string_to_array ( column_names, ',' ) ) ) AS column_name
        FROM natural_keys
),
types AS (
    SELECT schemas.schema_oid,
            schemas.schema_name,
            t.oid AS object_oid,
            split_part ( pg_catalog.format_type ( t.oid, NULL ), '.', 2 ) AS object_name,
            CASE
                WHEN t.typrelid != 0 THEN CAST ( 'tuple' AS pg_catalog.text )
                WHEN t.typlen < 0 THEN CAST ( 'var' AS pg_catalog.text )
                ELSE CAST ( t.typlen AS pg_catalog.text )
                END AS object_type,
            t.typrelid
        FROM pg_catalog.pg_type t
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = t.typnamespace )
        WHERE ( t.typrelid = 0
                OR ( SELECT c.relkind = 'c'
                        FROM pg_catalog.pg_class c
                        WHERE c.oid = t.typrelid ) )
            AND NOT EXISTS (
                    SELECT 1
                        FROM pg_catalog.pg_type el
                        WHERE el.oid = t.typelem
                        AND el.typarray = t.oid )
),
type_cols AS (
    SELECT types.schema_oid,
            types.schema_name,
            types.object_oid,
            types.object_name,
            types.object_oid::bigint * 10000::bigint + a.attnum::bigint AS column_id,
            a.attname::text AS column_name,
            a.attnum AS ordinal_position,
            pg_catalog.format_type ( a.atttypid, a.atttypmod ) AS data_type,
            null::boolean AS is_nullable,
            null::boolean AS is_pk,
            null::boolean AS is_nk,
            pg_catalog.pg_get_expr ( ad.adbin, ad.adrelid ) AS column_default,
            null::text AS domain_name,
            pg_catalog.col_description ( a.attrelid, a.attnum ) AS comments
        FROM types
        JOIN pg_catalog.pg_attribute a
            ON ( a.attrelid = types.typrelid )
        LEFT JOIN pg_catalog.pg_attrdef ad
            ON ( a.attrelid = ad.adrelid
                AND a.attnum = ad.adnum )
        WHERE a.attnum > 0
            AND NOT a.attisdropped
)
SELECT col.schema_oid,
        col.schema_name::text AS schema_name,
        col.object_oid,
        col.object_name::text AS object_name,
        concat_ws ( '.', col.schema_name::text, col.object_name::text ) AS full_object_name,
        col.column_id,
        col.column_name::text AS column_name,
        col.ordinal_position,
        col.data_type,
        col.is_nullable,
        ( pk.column_name IS NOT NULL ) AS is_pk,
        ( nk.column_name IS NOT NULL ) AS is_nk,
        col.column_default,
        col.domain_name::text AS domain_name,
        col.comments
    FROM columns col
    LEFT JOIN pk_columns pk
        ON ( pk.schema_name = col.schema_name::text
            AND pk.object_name = col.object_name::text
            AND pk.column_name = col.column_name::text )
    LEFT JOIN nk_columns nk
        ON ( nk.schema_name = col.schema_name::text
            AND nk.object_name = col.object_name::text
            AND nk.column_name = col.column_name::text )
UNION
SELECT tc.schema_oid,
        tc.schema_name,
        tc.object_oid,
        tc.object_name,
        concat_ws ( '.', tc.schema_name, tc.object_name ) AS full_object_name,
        tc.column_id,
        tc.column_name,
        tc.ordinal_position,
        tc.data_type,
        null::boolean AS is_nullable,
        null::boolean AS is_pk,
        null::boolean AS is_nk,
        tc.column_default,
        null::text AS domain_name,
        tc.comments
    FROM type_cols tc
;

COMMENT ON VIEW util_meta.columns IS 'Metadata for the application database columns' ;

COMMENT ON COLUMN util_meta.columns.schema_oid IS 'The OID of the schema that contains the column.' ;
COMMENT ON COLUMN util_meta.columns.schema_name IS 'The name of the schema that contains the column.' ;
COMMENT ON COLUMN util_meta.columns.object_oid IS 'The OID of the object that contains the column.' ;
COMMENT ON COLUMN util_meta.columns.object_name IS 'The name of the object that contains the column.' ;
COMMENT ON COLUMN util_meta.columns.full_object_name IS 'The full name of the object that contains the column.' ;
COMMENT ON COLUMN util_meta.columns.column_id IS 'The calculated ID of the column (since there do not appear to be column OIDs).' ;
COMMENT ON COLUMN util_meta.columns.column_name IS 'The name of the column.' ;
COMMENT ON COLUMN util_meta.columns.ordinal_position IS 'The position of the column in the object.' ;
COMMENT ON COLUMN util_meta.columns.data_type IS 'The datatype of the column.' ;
COMMENT ON COLUMN util_meta.columns.is_nullable IS 'Indicates if the column is nullable.' ;
COMMENT ON COLUMN util_meta.columns.is_pk IS 'Indicates if the column is part of the primary key.' ;
COMMENT ON COLUMN util_meta.columns.is_nk IS 'Indicates if the column is part of the (primary) natural key.' ;
COMMENT ON COLUMN util_meta.columns.column_default IS 'The default value for the column (if any).' ;
COMMENT ON COLUMN util_meta.columns.domain_name IS 'The domain of the column (if any).' ;
COMMENT ON COLUMN util_meta.columns.comments IS 'The column comments' ;
