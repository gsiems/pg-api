CREATE OR REPLACE VIEW util_meta.typtypes
AS
SELECT *
    FROM (
        VALUES
            ( 'b', 'base type' ),
            ( 'c', 'composite type' ),
            ( 'd', 'domain' ),
            ( 'e', 'enum type' ),
            ( 't', 'pseudo-type' ),
            ( 'r', 'range type' ),
            ( 'm', 'multirange' )
        ) AS t ( typtype, label ) ;

COMMENT ON VIEW util_meta.typtypes IS 'Labels for pg_type.typtype values' ;
