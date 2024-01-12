CREATE OR REPLACE VIEW util_meta.contypes
AS
SELECT *
    FROM (
        VALUES
            ( 'f', 'FOREIGN KEY' ),
            ( 'p', 'PRIMARY KEY' ),
            ( 'u', 'UNIQUE' )
        ) AS t ( contype, label ) ;

COMMENT ON VIEW util_meta.contypes IS 'Labels for pg_constraint.contype values' ;
