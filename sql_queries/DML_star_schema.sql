-- =====================================================================
-- STAR SCHEMA ETL LOAD SCRIPT
-- =====================================================================
-- This script loads data from OLTP tables into the Star Schema
-- IMPORTANT: Tables must be loaded in DEPENDENCY ORDER (parents before children)
-- =====================================================================

-- =====================================================================
-- LOAD ORDER (Handles Dependencies)
-- =====================================================================
-- STEP 1: Load dimensions with NO dependencies first
--         dim_date, dim_specialty, dim_department, dim_encounter_type,
--         dim_diagnosis, dim_procedure, dim_patient
-- STEP 2: Load dimensions that DEPEND on other dimensions
--         dim_provider (depends on dim_specialty, dim_department)
-- STEP 3: Load fact table (depends on ALL dimensions)
--         fact_encounters
-- STEP 4: Load bridge tables (depend on fact table and dimensions)
--         bridge_encounter_diagnoses, bridge_encounter_procedures
-- =====================================================================


-- =====================================================================
-- STEP 1A: LOAD INDEPENDENT DIMENSIONS (No Foreign Key Dependencies)
-- =====================================================================

-- ===============================
-- dim_date (One-time load, no dependencies)
-- ===============================
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


-- ===============================
-- dim_specialty (No dependencies - simple lookup table)
-- ===============================
INSERT INTO dim_specialty (specialty_id, specialty_name, specialty_code)
SELECT specialty_id, specialty_name, specialty_code 
FROM specialties;


-- ===============================
-- dim_department (No dependencies - simple lookup table)
-- ===============================
INSERT INTO dim_department (department_id, department_name, floor, capacity)
SELECT department_id, department_name, floor, capacity
FROM departments;


-- ===============================
-- dim_encounter_type (Static reference data - no dependencies)
-- ===============================
INSERT INTO dim_encounter_type (encounter_type_name)
SELECT DISTINCT encounter_type 
FROM encounters;


-- ===============================
-- dim_diagnosis (No dependencies - lookup table)
-- ===============================
INSERT INTO dim_diagnosis (diagnosis_id, icd10_code, icd10_description)
SELECT diagnosis_id, icd10_code, icd10_description
FROM diagnoses;


-- ===============================
-- dim_procedure (No dependencies - lookup table)
-- ===============================
INSERT INTO dim_procedure (procedure_id, cpt_code, cpt_description)
SELECT procedure_id, cpt_code, cpt_description
FROM procedures;


-- ===============================
-- dim_patient (SCD Type 2 - No dependencies)
-- ===============================
INSERT INTO dim_patient (
    patient_id,
    first_name,
    last_name,
    gender,
    date_of_birth,
    age,
    age_group,
    mrn,
    effective_start_date,
    effective_end_date,
    is_current
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
    p.mrn,
    CURDATE() AS effective_start_date,  -- SCD Type 2
    NULL AS effective_end_date,          -- NULL = current version
    TRUE AS is_current                   -- Current version flag
FROM patients p;


-- =====================================================================
-- STEP 1B: LOAD DIMENSIONS WITH DEPENDENCIES
-- =====================================================================

-- ===============================
-- dim_provider (SCD Type 2)
-- DEPENDS ON: dim_specialty, dim_department (must be loaded first!)
-- ===============================
-- Check: dim_specialty and dim_department must have data before this runs
INSERT INTO dim_provider (
    provider_id, 
    first_name, 
    last_name, 
    credential,
    effective_start_date,
    effective_end_date,
    is_current
)
SELECT 
    p.provider_id,
    p.first_name,
    p.last_name,
    p.credential,
    p.specialty_id,
    CURDATE() AS effective_start_date,  -- SCD Type 2
    NULL AS effective_end_date,          -- NULL = current version
    TRUE AS is_current                   -- Current version flag
FROM providers p



-- =====================================================================
-- STEP 2: LOAD FACT TABLE
-- =====================================================================


INSERT INTO fact_encounters (
    encounter_id,
    -- Date dimension surrogate keys
    encounter_date_key,    
    discharge_date_key,
    -- Dimension foreign keys
    patient_key,
    provider_key,
    specialty_key,
    department_key,
    encounter_type_key,
    -- Exact date and time values from source (OLTP)
    encounter_date,
    discharge_date,
    length_of_stay_days,
    
    -- Denormalized attributes 
    specialty_name,
    encounter_type_name,
    encounter_year,
    encounter_month,
    encounter_month_name,
    
    -- Pre-aggregated metrics
    diagnosis_count,
    procedure_count,
    total_claim_amount,
    total_allowed_amount,
    billing_count,
    -- Readmission analysis fields
    is_inpatient,
    is_readmission,
    days_since_last_discharge
)
SELECT 
    e.encounter_id,
    
    -- Date keys (lookup from dim_date)
    DATE_FORMAT(e.encounter_date, '%Y%m%d') AS encounter_date_key,
    CASE 
        WHEN e.discharge_date IS NOT NULL 
        THEN DATE_FORMAT(e.discharge_date, '%Y%m%d')
        ELSE NULL 
    END AS discharge_date_key,
    
    -- DIMENSION KEY LOOKUPS 
    -- Each lookup finds the surrogate key from the dimension table
    dp.patient_key,           -- Lookup from dim_patient
    dprov.provider_key,       -- Lookup from dim_provider
    ds.specialty_key,         -- Lookup from dim_specialty
    dd.department_key,        -- Lookup from dim_department
    det.encounter_type_key,   -- Lookup from dim_encounter_type
    
    -- Encounter details
    e.encounter_date,
    e.discharge_date,
    CASE 
        WHEN e.discharge_date IS NOT NULL 
        THEN DATEDIFF(e.discharge_date, e.encounter_date)
        ELSE NULL 
    END AS length_of_stay_days,
    
    -- DENORMALIZED: Copy from dimensions to avoid JOINs
    ds.specialty_name,
    e.encounter_type,
    YEAR(e.encounter_date) AS encounter_year,
    MONTH(e.encounter_date) AS encounter_month,
    MONTHNAME(e.encounter_date) AS encounter_month_name,
    
    -- PRE-AGGREGATED: Diagnosis count (calculated at ETL time)
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
-- JOIN to dimensions to get surrogate keys
JOIN dim_patient dp ON e.patient_id = dp.patient_id AND dp.is_current = TRUE
JOIN dim_provider dprov ON e.provider_id = dprov.provider_id AND dprov.is_current = TRUE
JOIN dim_specialty ds ON dprov.specialty_id = ds.specialty_id
JOIN dim_department dd ON e.department_id = dd.department_id
JOIN dim_encounter_type det ON e.encounter_type = det.encounter_type_name;


-- =====================================================================
-- STEP 3: LOAD BRIDGE TABLES
-- =====================================================================

-- ===============================
-- Bridge: Encounter to Diagnoses
-- ===============================
INSERT INTO bridge_encounter_diagnoses (
    encounter_key, diagnosis_key, diagnosis_sequence
)
SELECT DISTINCT
    f.encounter_key,       -- From fact_encounters (must exist!)
    dd.diagnosis_key,      -- From dim_diagnosis (must exist!)
    ed.diagnosis_sequence
FROM encounter_diagnoses ed
JOIN fact_encounters f ON ed.encounter_id = f.encounter_id
JOIN dim_diagnosis dd ON ed.diagnosis_id = dd.diagnosis_id;


-- ===============================
-- Bridge: Encounter to Procedures
-- ===============================
INSERT INTO bridge_encounter_procedures (encounter_key, procedure_key, procedure_date)
SELECT 
    f.encounter_key,       -- From fact_encounters (must exist!)
    dp.procedure_key,      -- From dim_procedure (must exist!)
    ep.procedure_date
FROM encounter_procedures ep
JOIN fact_encounters f ON ep.encounter_id = f.encounter_id
JOIN dim_procedure dp ON ep.procedure_id = dp.procedure_id;

