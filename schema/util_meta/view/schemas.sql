CREATE OR REPLACE VIEW util_meta.schemas
AS
SELECT n.oid AS schema_oid,
        n.nspname::text AS schema_name,
        n.nspowner AS owner_oid,
        pg_catalog.pg_get_userbyid ( n.nspowner )::text AS owner_name,
        concat_ws ( '/', 'schema', n.nspname::text ) AS directory_name
    FROM pg_catalog.pg_namespace n
    LEFT JOIN pg_catalog.pg_extension px
        ON ( px.extnamespace = n.oid )
    WHERE n.nspname !~ '^pg_'
        AND n.nspname NOT IN ( 
            'information_schema', 
            'plprofiler_client', 
            'public', 
            'sde' 
            )
        AND px.oid IS NULL ;

COMMENT ON VIEW util_meta.schemas IS 'View of the application database schemas' ;
COMMENT ON COLUMN util_meta.schemas.schema_oid IS 'The OID of the schema.' ;
COMMENT ON COLUMN util_meta.schemas.schema_name IS 'The name of the schema.' ;
COMMENT ON COLUMN util_meta.schemas.owner_oid IS 'The OID of the owner of the schema.' ;
COMMENT ON COLUMN util_meta.schemas.owner_name IS 'The name of the owner of the schema.' ;
COMMENT ON COLUMN util_meta.schemas.directory_name IS 'The sub-directory in the (presumably git) repository that contains the schema DDL files.' ;
