-- sel.sql
CREATE TEMP TABLE temp_columns AS
SELECT ROW_NUMBER() OVER () AS ordinal_position,
       a.attname            AS column_name,
       c.relname            AS table_name,
       t.typname            AS type_name,
       d.description        AS column_comment,
       a.attnum,  -- Нужно для связки с другими временными таблицами
       a.attrelid -- Нужно для связки с другими временными таблицами
FROM pg_attribute a
         JOIN pg_class c ON a.attrelid = c.oid
         JOIN pg_namespace n ON c.relnamespace = n.oid
         JOIN pg_type t ON a.atttypid = t.oid
         LEFT JOIN pg_description d ON d.objoid = a.attrelid AND d.objsubid = a.attnum
WHERE n.nspname = :sch_name
  AND c.relkind = 'r'
  AND a.attnum > 0
  AND a.attname = :col_name;


CREATE TEMP TABLE temp_constraints AS
SELECT c.ordinal_position,
       con.conname,
       pg_get_constraintdef(con.oid) AS constraint_definition
FROM temp_columns c
         JOIN pg_constraint con ON con.conrelid = c.attrelid AND c.attnum = ANY (con.conkey);


CREATE TEMP TABLE temp_indexes AS
SELECT
    c.ordinal_position,
    i.relname AS index_name,
    am.amname AS index_type
FROM temp_columns c
         JOIN pg_index ix ON ix.indrelid = c.attrelid
         JOIN pg_class i ON i.oid = ix.indexrelid
         JOIN pg_am am ON i.relam = am.oid -- Тип индекса (например, btree, hash)
WHERE c.attnum = ANY(ix.indkey);


DO $$
    DECLARE

        no_header TEXT := 'No.';
        no_delimiter TEXT := '---';

        column_name_header TEXT := 'Имя столбца     ';
        column_name_delimiter TEXT := '----------------';

        table_name_header TEXT := 'Имя таблицы     ';
        table_name_delimiter TEXT := '----------------';

        attr_header TEXT := 'Атрибуты';
        attr_delimiter TEXT := '----------------------------------------------------------------------------';

        pointer_column CURSOR FOR (SELECT * FROM temp_columns c);
        constr RECORD;
        idx RECORD;
    BEGIN

        RAISE NOTICE E'\r%-|-%-|-%-|-%', no_delimiter, column_name_delimiter, table_name_delimiter, attr_delimiter;
        RAISE NOTICE E'\r% | % | % | %', no_header, column_name_header, table_name_header, attr_header;
        RAISE NOTICE E'\r%-|-%-|-%-|-%', no_delimiter, column_name_delimiter, table_name_delimiter, attr_delimiter;

        FOR col IN pointer_column LOOP

                RAISE NOTICE E'\r% | % | % | Type:   %',
                    RPAD(col.ordinal_position::TEXT, 3, ' '),
                    RPAD(col.column_name::TEXT, 16, ' '),
                    RPAD(col.table_name::TEXT, 16, ' '),
                    col.type_name;

                FOR constr IN (SELECT * FROM temp_constraints WHERE ordinal_position = col.ordinal_position) LOOP
                        RAISE NOTICE E'\r.   | % | % | Constr: %',
                            RPAD('', 16, ' '),
                            RPAD('', 16, ' '),
                            constr.constraint_definition;
                    END LOOP;

                FOR idx IN (SELECT * FROM temp_indexes WHERE ordinal_position = col.ordinal_position) LOOP
                        RAISE NOTICE E'\r.   | % | % | Index:  %',
                            RPAD('', 16, ' '),
                            RPAD('', 16, ' '),
                            idx.index_name;
                    END LOOP;


                IF col.column_comment IS NOT NULL THEN
                    RAISE NOTICE E'\r.   | % | % | Comment:%',
                        RPAD('', 16, ' '),
                        RPAD('', 16, ' '),
                        col.column_comment;
                END IF;


                RAISE NOTICE E'\r%-|-%-|-%-|-%', no_delimiter, column_name_delimiter, table_name_delimiter, attr_delimiter;

            END LOOP;

    END;
$$ LANGUAGE plpgsql;

DROP TABLE temp_indexes, temp_constraints, temp_columns;