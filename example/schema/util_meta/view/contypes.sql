CREATE OR REPLACE VIEW util_meta.contypes
AS
SELECT *
    FROM (
        VALUES
            ( 'f', 'FOREIGN KEY' ),
            ( 'p', 'PRIMARY KEY' ),
            ( 'u', 'UNIQUE' )
        ) AS t ( contype, label ) ;

COMMENT ON VIEW util_meta.contypes IS 'Labels for pg_constraint.contype (constraint type) values of interest' ;

COMMENT ON COLUMN util_meta.contypes.contype IS 'The pg_constraint.contype value' ;
COMMENT ON COLUMN util_meta.contypes.label IS 'The label/name associated with the contype value' ;
