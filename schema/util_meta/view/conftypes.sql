CREATE OR REPLACE VIEW util_meta.conftypes
AS
SELECT *
    FROM (
        VALUES
            ( 'a', 'NO ACTION' ),
            ( 'c', 'CASCADE' ),
            ( 'd', 'SET DEFAULT' ),
            ( 'f', 'FULL' ),
            ( 'n', 'SET NULL' ),
            ( 'p', 'PARTIAL' ),
            ( 'r', 'RESTRICT' ),
            ( 's', 'NONE' )
        ) AS t ( conftype, label ) ;

COMMENT ON VIEW util_meta.conftypes IS 'Labels for pg_constraint.confmatchtype, pg_constraint.confupdtype, and pg_constraint.confdeltype values' ;
