-- Populate patient into dim_patient
INSERT INTO dim_patient (
    patient_id,
    first_name,
    last_name,
    gender,
    date_of_birth,
    age,
    age_group,
    mrn
)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    p.gender,
    p.date_of_birth,
    TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) AS age,
    CASE
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) < 18 THEN '0-17'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 18 AND 35 THEN '18-35'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 36 AND 55 THEN '36-55'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 56 AND 70 THEN '56-70'
        ELSE '70+'
    END AS age_group,
    p.mrn
FROM patients p;

-- Handle Update in patient table in dim_patient
UPDATE dim_patient dp
JOIN patients p ON dp.patient_id = p.patient_id
SET
    dp.first_name = p.first_name,
    dp.last_name = p.last_name,
    dp.gender = p.gender,
    dp.date_of_birth = p.date_of_birth,
    dp.age = TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()),
    dp.age_group =
        CASE
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) < 18 THEN '0-17'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 18 AND 35 THEN '18-35'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 36 AND 55 THEN '36-55'
        WHEN TIMESTAMPDIFF(YEAR, p.date_of_birth, CURDATE()) BETWEEN 56 AND 70 THEN '56-70'
        ELSE '70+'
        END;
 
 
-- 	Dates Generation 
CREATE TABLE numbers (n INT PRIMARY KEY);

INSERT INTO numbers (n)
SELECT a.N + b.N * 10 + c.N * 100
FROM (SELECT 0 N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a,
     (SELECT 0 N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b,
     (SELECT 0 N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c;
      

-- Popluate dim_date	
INSERT INTO dim_date (
    date_key,
    calendar_date,
    year,
    month,
    month_name,
    quarter,
    day,
    day_of_week
)
SELECT
    DATE_FORMAT(d, '%Y%m%d') AS date_key,
    d AS calendar_date,
    YEAR(d),
    MONTH(d),
    MONTHNAME(d),
    QUARTER(d),
    DAY(d),
    DAYNAME(d)
FROM (
    SELECT DATE_ADD('2020-01-01', INTERVAL n DAY) d
    FROM numbers
) dates
WHERE d <= '2030-12-31';


-- populate specialty into dim_specialty


