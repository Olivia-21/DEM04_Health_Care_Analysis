-- Question 1: Monthly Encounters by Specialty
EXPLAIN ANALYZE
SELECT
    DATE_FORMAT(e.encounter_date, '%Y-%m') AS encounter_month,
    s.specialty_name,
    e.encounter_type,
    COUNT(*) AS total_encounters,
    COUNT(DISTINCT e.patient_id) AS unique_patients
FROM encounters e
JOIN providers p ON e.provider_id = p.provider_id
JOIN specialties s ON p.specialty_id = s.specialty_id
GROUP BY
    DATE_FORMAT(e.encounter_date, '%Y-%m'),
    s.specialty_name,
    e.encounter_type
ORDER BY encounter_month, specialty_name;


-- QUESTION 2: Top Diagnosis–Procedure Pairs
EXPLAIN ANALYZE
SELECT
    d.icd10_code,
    pr.cpt_code,
    COUNT(*) AS encounter_count
FROM encounter_diagnoses ed
JOIN diagnoses d ON ed.diagnosis_id = d.diagnosis_id
JOIN encounter_procedures ep ON ed.encounter_id = ep.encounter_id
JOIN procedures pr ON ep.procedure_id = pr.procedure_id
GROUP BY d.icd10_code, pr.cpt_code
ORDER BY encounter_count DESC;

-- Question 3: 30-Day Readmission Rate
EXPLAIN ANALYZE
SELECT
    s.specialty_name,
    COUNT(DISTINCT e1.encounter_id) AS readmissions
FROM encounters e1
JOIN encounters e2
    ON e1.patient_id = e2.patient_id
   AND e2.encounter_date > e1.discharge_date
   AND e2.encounter_date <= DATE_ADD(e1.discharge_date, INTERVAL 30 DAY)
JOIN providers p ON e2.provider_id = p.provider_id
JOIN specialties s ON p.specialty_id = s.specialty_id
WHERE e1.encounter_type = 'Inpatient'
GROUP BY s.specialty_name
ORDER BY readmissions DESC;


-- QUESTION 4: Revenue by Specialty and Month
EXPLAIN ANALYZE
SELECT
    DATE_FORMAT(b.claim_date, '%Y-%m') AS claim_month,
    s.specialty_name,
    SUM(b.allowed_amount) AS total_revenue
FROM billing b
JOIN encounters e ON b.encounter_id = e.encounter_id
JOIN providers p ON e.provider_id = p.provider_id
JOIN specialties s ON p.specialty_id = s.specialty_id
GROUP BY
    DATE_FORMAT(b.claim_date, '%Y-%m'),
    s.specialty_name
ORDER BY total_revenue DESC;

