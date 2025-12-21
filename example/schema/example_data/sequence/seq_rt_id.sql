/*

The goal is to minimize the number of reference table records that share a
matching ID.

The rational here is that, when the reference tables all have their own
sequences (or identity columns) then the reference data tables will all
probably start from 1 and will share a number of identical IDs. If a person is
writing queries and happens to mis-join the reference data tables then instead
of retrieving incorrect data they are more likely to retrieve no data, and
retrieving no data is a more obvious problem than retrieving incorrect data.

*/

CREATE SEQUENCE example_data.seq_rt_id
    INCREMENT BY 1
    MINVALUE 1 MAXVALUE 2147483647
    START WITH 1
    NO CYCLE ;
