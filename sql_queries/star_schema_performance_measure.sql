-- =====================================
--  STAR SCHEMA QUERIES
-- =====================================
-- Question 1: Monthly Encounters by Specialty
EXPLAIN ANALYZE
SELECT 
    f.encounter_year,
    f.encounter_month,
    f.encounter_month_name,
    f.specialty_name,
    f.encounter_type_name,
    COUNT(f.encounter_key) AS total_encounters,
    COUNT(DISTINCT f.patient_key) AS unique_patients
FROM fact_encounters f
GROUP BY 
    f.encounter_year,
    f.encounter_month,
    f.encounter_month_name,
    f.specialty_name,
    f.encounter_type_name
ORDER BY f.encounter_year, f.encounter_month, f.specialty_name, f.encounter_type_name;


-- Question 2: Diagnosis-Procedure Pairs
EXPLAIN ANALYZE
SELECT 
    d.icd10_code,
    d.icd10_description,
    pr.cpt_code,
    pr.cpt_description,
    COUNT(DISTINCT bd.encounter_key) AS encounter_count
FROM bridge_encounter_diagnoses bd
JOIN dim_diagnosis d ON bd.diagnosis_key = d.diagnosis_key
JOIN bridge_encounter_procedures bp ON bd.encounter_key = bp.encounter_key
JOIN dim_procedure pr ON bp.procedure_key = pr.procedure_key
GROUP BY 
    d.icd10_code,
    d.icd10_description,
    pr.cpt_code,
    pr.cpt_description
ORDER BY encounter_count DESC
LIMIT 20;

-- ===================================
-- Question 3: 30-Day Readmission Rate
-- ===================================
EXPLAIN ANALYZE
SELECT 
    f.specialty_name,
    COUNT(f.encounter_key) AS total_inpatient_discharges,
    SUM(f.is_readmission) AS readmission_count,
    ROUND(SUM(f.is_readmission) * 100.0 / COUNT(f.encounter_key), 2) AS readmission_rate_pct
FROM fact_encounters f
WHERE f.is_inpatient = TRUE
  AND f.discharge_date IS NOT NULL
GROUP BY f.specialty_name
ORDER BY readmission_rate_pct DESC;


-- ===================================
-- Question 4: Revenue by Specialty & Month
-- Uses denormalized: specialty_name, encounter_year, encounter_month, encounter_month_name
-- Uses pre-aggregated: total_allowed_amount
-- ===================================
EXPLAIN ANALYZE
SELECT 
    f.encounter_year,
    f.encounter_month,
    f.encounter_month_name,
    f.specialty_name,
    COUNT(f.encounter_key) AS encounter_count,
    SUM(f.total_allowed_amount) AS total_revenue,
    AVG(f.total_allowed_amount) AS avg_revenue_per_encounter
FROM fact_encounters f
GROUP BY 
    f.encounter_year,
    f.encounter_month,
    f.encounter_month_name,
    f.specialty_name
ORDER BY f.encounter_year, f.encounter_month, total_revenue DESC;
