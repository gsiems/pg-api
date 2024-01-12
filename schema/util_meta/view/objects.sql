CREATE OR REPLACE VIEW util_meta.objects
AS
WITH objs AS (
    -- procedures, functions, etc
    SELECT schemas.schema_oid,
            schemas.schema_name,
            p.oid AS object_oid,
            p.proname::text AS object_name,
            ( pg_catalog.pg_get_userbyid ( p.proowner ) )::text AS object_owner,
            concat_ws ( '.', schemas.schema_name, p.proname::text ) AS full_object_name,
            coalesce ( pt.label, 'function' ) AS object_type,
            null::bigint AS row_count,
            l.lanname::text AS procedure_language,
            ( pg_catalog.pg_get_function_result ( p.oid ) )::text AS result_data_type,
            pg_catalog.pg_get_function_arguments ( p.oid ) AS calling_arguments,
            pg_catalog.obj_description ( p.oid, 'pg_class' ) AS comments
        FROM pg_catalog.pg_proc p
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = p.pronamespace )
        JOIN pg_catalog.pg_language l
            ON ( p.prolang = l.oid )
        LEFT JOIN util_meta.prokinds pt
            ON ( pt.prokind = p.prokind::text )
    UNION
    -- triggers
    SELECT  schemas.schema_oid,
            schemas.schema_name,
            t.oid AS object_oid,
            t.tgname::text AS object_name,
            ( pg_catalog.pg_get_userbyid ( c.relowner ) )::text AS object_owner,
            concat_ws ( ' on ', t.tgname::text, concat_ws ( '.', schemas.schema_name, c.relname::text ) ) AS full_object_name,
            'trigger' AS object_type,
            null::bigint AS row_count,
            null::text AS procedure_language,
            null::text AS result_data_type,
            --pg_catalog.pg_get_function_arguments ( t.tgfoid ) AS calling_arguments,
            null::text AS calling_arguments,
            pg_catalog.obj_description ( t.oid, 'pg_trigger' ) AS comments
        FROM pg_catalog.pg_trigger t
        JOIN pg_catalog.pg_class c
            ON ( c.oid = t.tgrelid )
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = c.relnamespace )
        WHERE NOT t.tgisinternal
    UNION
    -- tables, views, and everything else
    SELECT schemas.schema_oid,
            schemas.schema_name,
            c.oid AS object_oid,
            c.relname::text AS object_name,
            ( pg_catalog.pg_get_userbyid ( c.relowner ) )::text AS object_owner,
            concat_ws ( '.', schemas.schema_name, c.relname::text ) AS full_object_name,
            CASE
                WHEN i.inhrelid IS NOT NULL THEN 'table partition'
                ELSE coalesce ( rt.label, c.relkind::text )
                END AS object_type,
            c.reltuples::bigint AS row_count,
            null::text as procedure_language,
            null::text AS result_data_type,
            null::text AS calling_arguments,
            pg_catalog.obj_description ( c.oid, 'pg_class' ) AS comments
        FROM pg_catalog.pg_class c
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = c.relnamespace )
        LEFT JOIN pg_catalog.pg_inherits i
            ON ( c.oid = i.inhrelid )
        LEFT JOIN util_meta.relkinds rt
            ON ( rt.relkind = c.relkind::text )
),
dirs AS (
    SELECT object_oid,
            CASE
                WHEN object_type IN ( 'foreign table', 'function', 'materialized view', 'procedure', 'table', 'trigger', 'type', 'view' )
                    THEN concat_ws ( '/', 'schema', schema_name, replace ( object_type, ' ', '_' ) )
                WHEN object_type = 'partitioned table'
                    THEN concat_ws ( '/', 'schema', schema_name, 'table' )
                -- NB Pg default ID seq names are: table_name || '_id_seq'
                -- ASSERTION: User defined sequences do not end with '_id_seq'.
                WHEN object_type = 'sequence' AND object_name !~ '_id_seq$'
                    THEN concat_ws ( '/', 'schema', schema_name, 'sequence' )
                END AS directory_name
    FROM objs
)
SELECT  objs.schema_oid,
        objs.schema_name,
        objs.object_oid,
        objs.object_name,
        objs.object_owner,
        objs.object_type,
        objs.full_object_name,
        objs.row_count,
        dirs.directory_name,
        CASE
            WHEN dirs.directory_name IS NOT NULL THEN object_name || '.sql'
            END AS file_name,
        objs.procedure_language,
        objs.result_data_type,
        objs.calling_arguments,
        objs.comments
    FROM objs
    LEFT JOIN dirs
        ON ( dirs.object_oid = objs.object_oid ) ;

COMMENT ON VIEW util_meta.objects IS 'Metadata for the application database objects' ;

COMMENT ON COLUMN util_meta.objects.schema_oid IS 'The OID of the schema that contains the object.' ;
COMMENT ON COLUMN util_meta.objects.schema_name IS 'The name of the schema that contains the object.' ;
COMMENT ON COLUMN util_meta.objects.object_oid IS 'The OID of the database object.' ;
COMMENT ON COLUMN util_meta.objects.object_name IS 'The name of the database object.' ;
COMMENT ON COLUMN util_meta.objects.object_owner IS 'The owner of the database object.' ;
COMMENT ON COLUMN util_meta.objects.object_type IS 'The type of the database object.' ;
COMMENT ON COLUMN util_meta.objects.full_object_name IS 'The full name (schema name plus object name ) of the database object.' ;
COMMENT ON COLUMN util_meta.objects.row_count IS 'The estimated number (based on db stats) of rows (for tables).' ;
COMMENT ON COLUMN util_meta.objects.directory_name IS 'The sub-directory in the git repository that contains the object DDL file.' ;
COMMENT ON COLUMN util_meta.objects.file_name IS 'The filename in the (presumably git) repository that contains the object DDL.' ;
COMMENT ON COLUMN util_meta.objects.procedure_language IS 'The language that the function or procedure is written in.' ;
COMMENT ON COLUMN util_meta.objects.result_data_type IS 'The datatype of the function result.' ;
COMMENT ON COLUMN util_meta.objects.calling_arguments IS 'The names and datatypes of the calling arguments to the function or procedure.' ;
COMMENT ON COLUMN util_meta.objects.comments IS 'The database comments for the object.' ;
