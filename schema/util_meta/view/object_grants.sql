CREATE OR REPLACE VIEW util_meta.object_grants
AS
WITH rol AS (
    SELECT oid,
            rolname::text AS role_name
        FROM pg_authid
    UNION
    SELECT 0::oid AS oid,
            'public'::text
),
namespace_base AS (
    SELECT schemas.schema_oid,
            schemas.schema_name::text AS object_schema,
            n.oid,
            n.nspname::text AS object_name,
            n.nspowner AS owner_oid,
            'schema'::text AS object_type,
            coalesce ( n.nspacl, acldefault ( 'n'::"char", n.nspowner ) ) AS acl
        FROM pg_namespace n
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = n.oid )
),
namespaces AS (
    SELECT object_schema,
            oid,
            object_name,
            object_type,
            owner_oid,
            ( aclexplode ( acl ) ).grantor AS grantor_oid,
            ( aclexplode ( acl ) ).grantee AS grantee_oid,
            ( aclexplode ( acl ) ).privilege_type AS privilege_type,
            ( aclexplode ( acl ) ).is_grantable AS is_grantable
        FROM namespace_base
),
class_base AS (
    SELECT schemas.schema_oid,
            schemas.schema_name::text AS object_schema,
            c.oid,
            c.relname::text AS object_name,
            c.relowner AS owner_oid,
            CASE
                WHEN c.relkind = 'r' THEN 'table'
                WHEN c.relkind = 'v' THEN 'view'
                WHEN c.relkind = 'm' THEN 'materialized view'
                WHEN c.relkind = 'c' THEN 'type'
                WHEN c.relkind = 'i' THEN 'index'
                WHEN c.relkind = 'S' THEN 'sequence'
                WHEN c.relkind = 's' THEN 'special'
                WHEN c.relkind = 't' THEN 'TOAST table'
                WHEN c.relkind = 'f' THEN 'foreign table'
                WHEN c.relkind = 'p' THEN 'partitioned table'
                WHEN c.relkind = 'I' THEN 'partitioned index'
                ELSE c.relkind::text
                END AS object_type,
            CASE
                WHEN c.relkind = 'S' THEN coalesce ( c.relacl, acldefault ( 's'::"char", c.relowner ) )
                ELSE coalesce ( c.relacl, acldefault ( 'r'::"char", c.relowner ) )
                END AS acl
        FROM pg_class c
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = c.relnamespace )
        WHERE c.relkind IN ( 'r', 'v', 'm', 'S', 'f', 'p' )
),
classes AS (
    SELECT object_schema,
            oid,
            object_name,
            object_type,
            owner_oid,
            ( aclexplode ( acl ) ).grantor AS grantor_oid,
            ( aclexplode ( acl ) ).grantee AS grantee_oid,
            ( aclexplode ( acl ) ).privilege_type AS privilege_type,
            ( aclexplode ( acl ) ).is_grantable AS is_grantable
        FROM class_base
),
proc_base AS (
    SELECT schemas.schema_oid,
            schemas.schema_name::text AS object_schema,
            p.oid,
            p.proname::text AS object_name,
            p.proowner AS owner_oid,
            CASE p.prokind
                WHEN 'a' THEN 'aggregate'
                WHEN 'w' THEN 'window'
                WHEN 'p' THEN 'procedure'
                ELSE 'function'
                END AS object_type,
            coalesce ( p.proacl, acldefault ( 'f'::"char", p.proowner ) ) AS acl
        FROM pg_proc p
        JOIN util_meta.schemas
            ON ( schemas.schema_oid = p.pronamespace )
),
procs AS (
    SELECT object_schema,
            oid,
            object_name,
            object_type,
            owner_oid,
            pg_catalog.pg_get_function_arguments ( oid ) AS calling_arguments,
            ( aclexplode ( acl ) ).grantor AS grantor_oid,
            ( aclexplode ( acl ) ).grantee AS grantee_oid,
            ( aclexplode ( acl ) ).privilege_type AS privilege_type,
            ( aclexplode ( acl ) ).is_grantable AS is_grantable
        FROM proc_base
),
udt_base AS (
    SELECT schemas.schema_oid,
            schemas.schema_name::text AS object_schema,
            t.oid,
            t.typname::text AS object_name,
            t.typowner AS owner_oid,
            CASE t.typtype
                WHEN 'b' THEN 'base type'
                WHEN 'c' THEN 'composite type'
                WHEN 'd' THEN 'domain'
                WHEN 'e' THEN 'enum type'
                WHEN 't' THEN 'pseudo-type'
                WHEN 'r' THEN 'range type'
                WHEN 'm' THEN 'multirange'
                ELSE t.typtype::text
                END AS object_type,
            coalesce ( t.typacl, acldefault ( 'T'::"char", t.typowner ) ) AS acl
        FROM pg_type t
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
        --AND t.typtype NOT IN ( 'p' )
        --AND NOT ( t.typtype = 'c'
        --    AND n.nspname = 'pg_catalog' )
),
udts AS (
    SELECT object_schema,
            oid,
            object_name,
            object_type,
            owner_oid,
            ( aclexplode ( acl ) ).grantor AS grantor_oid,
            ( aclexplode ( acl ) ).grantee AS grantee_oid,
            ( aclexplode ( acl ) ).privilege_type AS privilege_type,
            ( aclexplode ( acl ) ).is_grantable AS is_grantable
        FROM udt_base
),
fdw_base AS (
    SELECT null::oid AS schema_oid,
            null::text AS object_schema,
            p.oid,
            p.fdwname::text AS object_name,
            p.fdwowner AS owner_oid,
            'foreign data wrapper' AS object_type,
            coalesce ( p.fdwacl, acldefault ( 'F'::"char", p.fdwowner ) ) AS acl
        FROM pg_foreign_data_wrapper p
),
fdws AS (
    SELECT object_schema,
            oid,
            object_name,
            object_type,
            owner_oid,
            ( aclexplode ( acl ) ).grantor AS grantor_oid,
            ( aclexplode ( acl ) ).grantee AS grantee_oid,
            ( aclexplode ( acl ) ).privilege_type AS privilege_type,
            ( aclexplode ( acl ) ).is_grantable AS is_grantable
        FROM fdw_base
),
fsrv_base AS (
    SELECT null::oid AS schema_oid,
            null::text AS object_schema,
            p.oid,
            p.srvname::text AS object_name,
            p.srvowner AS owner_oid,
            'foreign server' AS object_type,
            coalesce ( p.srvacl, acldefault ( 'S'::"char", p.srvowner ) ) AS acl
        FROM pg_foreign_server p
),
fsrvs AS (
    SELECT object_schema,
            oid,
            object_name,
            object_type,
            owner_oid,
            ( aclexplode ( acl ) ).grantor AS grantor_oid,
            ( aclexplode ( acl ) ).grantee AS grantee_oid,
            ( aclexplode ( acl ) ).privilege_type AS privilege_type,
            ( aclexplode ( acl ) ).is_grantable AS is_grantable
        FROM fsrv_base
)
-- schema privileges
SELECT namespaces.object_schema,
        namespaces.object_type,
        namespaces.object_name,
        null::text AS calling_arguments,
        owner.role_name AS object_owner,
        grantor.role_name AS grantor,
        grantee.role_name AS grantee,
        namespaces.privilege_type,
        namespaces.is_grantable
    FROM namespaces
    JOIN rol owner
        ON ( owner.oid = namespaces.owner_oid )
    JOIN rol grantor
        ON ( grantor.oid = namespaces.grantor_oid )
    JOIN rol grantee
        ON ( grantee.oid = namespaces.grantee_oid )
    WHERE grantor.oid <> grantee.oid
UNION
-- class privileges
SELECT classes.object_schema,
        classes.object_type,
        classes.object_name,
        null::text AS calling_arguments,
        owner.role_name AS object_owner,
        grantor.role_name AS grantor,
        grantee.role_name AS grantee,
        classes.privilege_type,
        classes.is_grantable
    FROM classes
    JOIN rol owner
        ON ( owner.oid = classes.owner_oid )
    JOIN rol grantor
        ON ( grantor.oid = classes.grantor_oid )
    JOIN rol grantee
        ON ( grantee.oid = classes.grantee_oid )
    WHERE grantor.oid <> grantee.oid
UNION
-- routine_privileges
SELECT procs.object_schema,
        procs.object_type,
        procs.object_name,
        procs.calling_arguments,
        owner.role_name AS object_owner,
        grantor.role_name AS grantor,
        grantee.role_name AS grantee,
        procs.privilege_type,
        procs.is_grantable
    FROM procs
    JOIN rol owner
        ON ( owner.oid = procs.owner_oid )
    JOIN rol grantor
        ON ( grantor.oid = procs.grantor_oid )
    JOIN rol grantee
        ON ( grantee.oid = procs.grantee_oid )
    WHERE grantor.oid <> grantee.oid
UNION
-- udt_privileges
SELECT udts.object_schema,
        udts.object_type,
        udts.object_name,
        null::text AS calling_arguments,
        owner.role_name AS object_owner,
        grantor.role_name AS grantor,
        grantee.role_name AS grantee,
        udts.privilege_type,
        udts.is_grantable
    FROM udts
    JOIN rol owner
        ON ( owner.oid = udts.owner_oid )
    JOIN rol grantor
        ON ( grantor.oid = udts.grantor_oid )
    JOIN rol grantee
        ON ( grantee.oid = udts.grantee_oid )
    WHERE grantor.oid <> grantee.oid
UNION
-- fdw privileges
SELECT fdws.object_schema,
        fdws.object_type,
        fdws.object_name,
        null::text AS calling_arguments,
        owner.role_name AS object_owner,
        grantor.role_name AS grantor,
        grantee.role_name AS grantee,
        fdws.privilege_type,
        fdws.is_grantable
    FROM fdws
    JOIN rol owner
        ON ( owner.oid = fdws.owner_oid )
    JOIN rol grantor
        ON ( grantor.oid = fdws.grantor_oid )
    JOIN rol grantee
        ON ( grantee.oid = fdws.grantee_oid )
    WHERE grantor.oid <> grantee.oid
UNION
-- foreign servers
SELECT fsrvs.object_schema,
        fsrvs.object_type,
        fsrvs.object_name,
        null::text AS calling_arguments,
        owner.role_name AS object_owner,
        grantor.role_name AS grantor,
        grantee.role_name AS grantee,
        fsrvs.privilege_type,
        fsrvs.is_grantable
    FROM fsrvs
    JOIN rol owner
        ON ( owner.oid = fsrvs.owner_oid )
    JOIN rol grantor
        ON ( grantor.oid = fsrvs.grantor_oid )
    JOIN rol grantee
        ON ( grantee.oid = fsrvs.grantee_oid )
    WHERE grantor.oid <> grantee.oid ;

COMMENT ON VIEW util_meta.object_grants IS 'Privilege grants for application database objects' ;

COMMENT ON COLUMN util_meta.object_grants.object_schema IS 'The name of the schema that contains the object.' ;
COMMENT ON COLUMN util_meta.object_grants.object_name IS 'The name of the database object.' ;
COMMENT ON COLUMN util_meta.object_grants.object_type IS 'The type of the database object.' ;
COMMENT ON COLUMN util_meta.object_grants.grantor IS 'The user/role that granted the privilege' ;
COMMENT ON COLUMN util_meta.object_grants.grantee IS 'The user/role that the privilege was granted to' ;
COMMENT ON COLUMN util_meta.object_grants.privilege_type IS 'The type of privilege' ;
COMMENT ON COLUMN util_meta.object_grants.is_grantable IS 'Indicates if the privilege is grantable' ;
