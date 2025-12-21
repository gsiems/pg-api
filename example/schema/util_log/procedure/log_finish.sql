CREATE OR REPLACE PROCEDURE util_log.log_finish ()
LANGUAGE plpgsql
AS $$
/**
Procedure log_finish is used to log the conclusion of a function/procedure.

Takes no arguments and simply adds an "Info" entry in the log with the text of
"finished".

*/
BEGIN
    call util_log.log_to_dblink ( 40, 'finished' ) ;
END ;
$$ ;
