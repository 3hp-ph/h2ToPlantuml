-- gather data for the ER diagram
drop table ER_COLUMNS;
create table ER_COLUMNS as
SELECT
  C.TABLE_NAME,
  C.COLUMN_NAME,
  C.DATA_TYPE,
  C.IS_NULLABLE,
  -- Check if this column is a foreign key
  COALESCE((
    SELECT CCU.TABLE_NAME
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE KCU
    JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC
      ON KCU.CONSTRAINT_NAME = TC.CONSTRAINT_NAME
     AND TC.CONSTRAINT_TYPE = 'FOREIGN KEY'
    JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CCU
      ON TC.CONSTRAINT_NAME = CCU.CONSTRAINT_NAME
    WHERE KCU.TABLE_NAME = C.TABLE_NAME
      AND KCU.COLUMN_NAME = C.COLUMN_NAME
    FETCH FIRST ROW ONLY
  ), '') AS REFERENCED_TABLE,
  -- Check if this column is a primary key
  CASE WHEN EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE PKCU
    JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PKTC
      ON PKCU.CONSTRAINT_NAME = PKTC.CONSTRAINT_NAME
     AND PKTC.CONSTRAINT_TYPE = 'PRIMARY KEY'
    WHERE PKCU.TABLE_NAME = C.TABLE_NAME
      AND PKCU.COLUMN_NAME = C.COLUMN_NAME
  ) THEN 'YES' ELSE 'NO' END AS IS_PK
FROM INFORMATION_SCHEMA.COLUMNS C
WHERE C.TABLE_SCHEMA = 'PUBLIC'
  -- exclude tables used for the ER diagram itself
  AND C.TABLE_NAME NOT IN ('ER_COLUMNS', 'ER_ENTITIES', 'ER_RELATIONS')
ORDER BY C.TABLE_NAME, IS_PK desc, C.COLUMN_NAME;

-- generate text for the columns
alter table ER_COLUMNS add TEXT VARCHAR(255) as
CASE
WHEN IS_PK = 'YES' THEN '* ' || column_name || ': ' || data_type || ' <PK>'
WHEN REFERENCED_TABLE <> '' THEN column_name || ': ' || data_type || ' <FK>'
ELSE column_name || ': ' || data_type
END;

-- generate text for the entities
drop table ER_ENTITIES;
create table ER_ENTITIES as
SELECT 
  TABLE_NAME,
  REGEXP_REPLACE(
    'entity ' || TABLE_NAME || ' {' || CHAR(10) || LISTAGG(TEXT, CHAR(10)) || CHAR(10) || '}', 
    '<PK>(?!.*<PK>)', 
    '<PK>' || CHAR(10) || '--')
   AS TEXT
FROM ER_COLUMNS
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- Generate text for the arrows between entities
drop table ER_RELATIONS;
create table ER_RELATIONS as
SELECT 
case
when is_nullable = 'YES' then
  TABLE_NAME || ' }--o| ' || REFERENCED_TABLE
else TABLE_NAME || ' }--|| ' || REFERENCED_TABLE
end as TEXT
FROM ER_COLUMNS
where REFERENCED_TABLE <> '';


---- Generate the final ER diagram text
SELECT 
'@startuml
hide circle
skinparam linetype ortho
left to right direction
' || LISTAGG(TEXT, CHAR(10)) || '
@enduml'
as TEXT FROM (
SELECT LISTAGG(TEXT, CHAR(10)) as TEXT FROM ER_ENTITIES
union all
SELECT LISTAGG(TEXT, CHAR(10)) as TEXT FROM ER_RELATIONS);