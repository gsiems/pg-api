CREATE OR REPLACE VIEW util_meta.dependencies
AS
WITH types AS (
    SELECT *
        FROM (
            VALUES
                ( 'c', 'type' ),
                ( 'f', 'foreign table' ),
                ( 'i', 'index' ),
                ( 'm', 'materialized view' ),
                ( 'p', 'partitioned table' ),
                ( 'r', 'table' ),
                ( 's', 'special' ),
                ( 't', 'TOAST table' ),
                ( 'v', 'view' ),
                ( 'I', 'partitioned index' ),
                ( 'S', 'sequence' )
            ) AS t ( obj_kind, object_type )
),
dependents AS (
    SELECT ev_class,
            split_part ( regexp_split_to_table ( ev_action, ':relid ' ), ' ', 1 ) AS dependent_oid
        FROM pg_rewrite
),
dep_map AS (
    SELECT ev_class AS parent_oid,
            dependent_oid::oid AS child_oid
        FROM dependents
        WHERE dependent_oid NOT LIKE '%QUERY'
            AND ev_class <> dependent_oid::oid
)
SELECT DISTINCT schemas.schema_oid,
        schemas.schema_name,
        c.oid AS object_oid,
        c.relname::text AS object_name,
        pg_catalog.pg_get_userbyid ( c.relowner )::text AS owner_name,
        coalesce ( obj_type.object_type, 'other (' || c.relkind || ')' ) AS object_type,
        dep_schemas.schema_oid AS dep_schema_oid,
        dep_schemas.schema_name AS dep_schema_name,
        c2.oid AS dep_object_oid,
        c2.relname ::text AS dep_object_name,
        pg_catalog.pg_get_userbyid ( c2.relowner )::text AS dep_owner_name,
        coalesce ( dep_type.object_type, 'other (' || c2.relkind || ')' ) AS dep_object_type
    FROM pg_catalog.pg_class c
    JOIN dep_map d
        ON ( c.oid = d.child_oid )
    JOIN pg_catalog.pg_class c2
        ON ( c2.oid = d.parent_oid )
    JOIN util_meta.schemas
        ON ( schemas.schema_oid = c.relnamespace )
    JOIN util_meta.schemas dep_schemas
        ON ( dep_schemas.schema_oid = c2.relnamespace )
    LEFT JOIN types AS obj_type
        ON ( obj_type.obj_kind = c.relkind )
    LEFT JOIN types AS dep_type
        ON ( dep_type.obj_kind = c2.relkind ) ;

COMMENT ON VIEW util_meta.dependencies IS 'View of the application database object dependencies' ;
COMMENT ON COLUMN util_meta.dependencies.schema_oid IS 'The OID of the schema.' ;
COMMENT ON COLUMN util_meta.dependencies.schema_name IS 'The name of the schema.' ;
COMMENT ON COLUMN util_meta.dependencies.object_oid IS 'The OID of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.object_name IS 'The name of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.owner_name IS 'The name of the owner of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.object_type IS 'The type of the object.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_schema_oid IS 'The OID of the dependent schema.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_schema_name IS 'The name of the dependent schema.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_object_oid IS 'The OID of the dependent object.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_object_name IS 'The name of the dependent object.' ;
COMMENT ON COLUMN util_meta.dependencies.dep_owner_name IS 'The name of the owner of the dependent object.' ;
COMMENT ON COLUMN util_meta.dependencies.object_type IS 'The type of the dependent object.' ;
