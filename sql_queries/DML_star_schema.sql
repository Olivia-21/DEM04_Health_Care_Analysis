-- ================= ===============
-- Populate patient into dim_patient
-- ================= ===============
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


-- ================= ===================
-- populate provider into dim_provider
-- ================= ====================
INSERT INTO dim_provider (provider_id, first_name, last_name, credential,
                          specialty_id, specialty_name, specialty_code,
                          department_id, department_name)
SELECT 
    p.provider_id,
    p.first_name,
    p.last_name,
    p.credential,
    p.specialty_id,
    s.specialty_name,  -- DENORMALIZED
    s.specialty_code,  -- DENORMALIZED
    p.department_id,
    d.department_name  -- DENORMALIZED
FROM providers p
JOIN specialties s ON p.specialty_id = s.specialty_id
JOIN departments d ON p.department_id = d.department_id;


-- Load dim_diagnosis
INSERT INTO dim_diagnosis (diagnosis_id, icd10_code, icd10_description)
SELECT diagnosis_id, icd10_code, icd10_description
FROM diagnoses;


-- Load dim_procedure
INSERT INTO dim_procedure (procedure_id, cpt_code, cpt_description)
SELECT procedure_id, cpt_code, cpt_description
FROM procedures;


-- ================= ===========================
-- Handle Update in patient table in dim_patient
-- ================= ============================
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
 
-- ================= 
-- 	Dates Generation 
-- ================= 

SET @@cte_max_recursion_depth = 5000;
INSERT INTO dim_date (
    date_key, calendar_date, year, month, month_name, quarter, day, day_of_week
)
WITH RECURSIVE date_range AS (
    SELECT DATE('2020-01-01') AS d
    UNION ALL
    SELECT DATE_ADD(d, INTERVAL 1 DAY)
    FROM date_range
    WHERE d < '2026-12-31'
)
SELECT
    DATE_FORMAT(d, '%Y%m%d'),
    d,
    YEAR(d),
    MONTH(d),
    MONTHNAME(d),
    QUARTER(d),
    DAY(d),
    DAYNAME(d)
FROM date_range;


-- ================= ===================
-- populate specialty into dim_specialty
-- ================= ====================
INSERT INTO dim_specialty (specialty_id, specialty_name, specialty_code)
SELECT specialty_id, specialty_name, specialty_code 
FROM specialties;



-- ================= ===================
-- populate department into dim_department
-- ================= ====================
INSERT INTO dim_department (department_id, department_name, floor, capacity)
SELECT department_id, department_name, floor, capacity
from departments;

-- =======================
-- Fact Table 
-- =======================

select * from fact_encounters;
INSERT INTO fact_encounters (
    encounter_id,
    encounter_date_key,
    discharge_date_key,
    patient_key,
    provider_key,
    specialty_key,
    department_key,
    encounter_type_key,
    encounter_date,
    discharge_date,
    length_of_stay_days,
    diagnosis_count,
    procedure_count,
    total_claim_amount,
    total_allowed_amount,
    billing_count,
    is_inpatient,
    is_readmission,
    days_since_last_discharge
)
SELECT 
    e.encounter_id,
    -- Date keys
    DATE_FORMAT(e.encounter_date, '%Y%m%d') AS encounter_date_key,
    CASE 
        WHEN e.discharge_date IS NOT NULL 
        THEN DATE_FORMAT(e.discharge_date, '%Y%m%d')
        ELSE NULL 
    END AS discharge_date_key,
    
    -- Dimension keys (lookup surrogate keys)
    dp.patient_key,
    dprov.provider_key,
    ds.specialty_key,
    dd.department_key,
    det.encounter_type_key,
    
    -- Encounter details
    e.encounter_date,
    e.discharge_date,
    CASE 
        WHEN e.discharge_date IS NOT NULL 
        THEN DATEDIFF(e.discharge_date, e.encounter_date)
        ELSE NULL 
    END AS length_of_stay_days,
    
    -- PRE-AGGREGATED: Diagnosis count
    (SELECT COUNT(*) 
     FROM encounter_diagnoses ed 
     WHERE ed.encounter_id = e.encounter_id) AS diagnosis_count,
    
    -- PRE-AGGREGATED: Procedure count
    (SELECT COUNT(*) 
     FROM encounter_procedures ep 
     WHERE ep.encounter_id = e.encounter_id) AS procedure_count,
    
    -- PRE-AGGREGATED: Billing totals
    COALESCE((SELECT SUM(b.claim_amount) 
              FROM billing b 
              WHERE b.encounter_id = e.encounter_id), 0) AS total_claim_amount,
    
    COALESCE((SELECT SUM(b.allowed_amount) 
              FROM billing b 
              WHERE b.encounter_id = e.encounter_id), 0) AS total_allowed_amount,
    
    COALESCE((SELECT COUNT(*) 
              FROM billing b 
              WHERE b.encounter_id = e.encounter_id), 0) AS billing_count,
    
    -- Readmission analysis fields
    (e.encounter_type = 'Inpatient') AS is_inpatient,
    
    -- PRE-COMPUTED: Is this a 30-day readmission?
    CASE 
        WHEN e.encounter_type = 'Inpatient' 
             AND e.discharge_date IS NOT NULL
             AND EXISTS (
                 SELECT 1 
                 FROM encounters prev
                 WHERE prev.patient_id = e.patient_id
                   AND prev.encounter_type = 'Inpatient'
                   AND prev.discharge_date IS NOT NULL
                   AND prev.discharge_date < e.encounter_date
                   AND DATEDIFF(e.encounter_date, prev.discharge_date) <= 30
             )
        THEN TRUE
        ELSE FALSE
    END AS is_readmission,
    
    -- Days since last discharge
    CASE 
        WHEN e.encounter_type = 'Inpatient' AND e.discharge_date IS NOT NULL
        THEN (
            SELECT DATEDIFF(e.encounter_date, MAX(prev.discharge_date))
            FROM encounters prev
            WHERE prev.patient_id = e.patient_id
              AND prev.encounter_type = 'Inpatient'
              AND prev.discharge_date IS NOT NULL
              AND prev.discharge_date < e.encounter_date
        )
        ELSE NULL
    END AS days_since_last_discharge
    
FROM encounters e
-- Join to dimensions to get surrogate keys
JOIN dim_patient dp ON e.patient_id = dp.patient_id
JOIN dim_provider dprov ON e.provider_id = dprov.provider_id
JOIN dim_specialty ds ON dprov.specialty_id = ds.specialty_id
JOIN dim_department dd ON e.department_id = dd.department_id
JOIN dim_encounter_type det ON e.encounter_type = det.encounter_type_name;


-- =====================================================================
-- STEP 3: LOAD BRIDGE TABLES
-- =====================================================================

-- ==============================
-- Bridge: Encounter to Diagnoses
-- ==============================
INSERT INTO bridge_encounter_diagnoses (
    encounter_key, diagnosis_key, diagnosis_sequence
)
SELECT DISTINCT
    f.encounter_key,
    dd.diagnosis_key,
    ed.diagnosis_sequence
FROM encounter_diagnoses ed
JOIN fact_encounters f ON ed.encounter_id = f.encounter_id
JOIN dim_diagnosis dd ON ed.diagnosis_id = dd.diagnosis_id;



-- ===============================
-- Bridge: Encounter to Procedures
-- ===============================
INSERT INTO bridge_encounter_procedures (encounter_key, procedure_key, procedure_date)
SELECT 
    f.encounter_key,
    dp.procedure_key,
    ep.procedure_date
FROM encounter_procedures ep
JOIN fact_encounters f ON ep.encounter_id = f.encounter_id
JOIN dim_procedure dp ON ep.procedure_id = dp.procedure_id;


-- SET FOREIGN_KEY_CHECKS = 0;
-- SET FOREIGN_KEY_CHECKS = 1;






