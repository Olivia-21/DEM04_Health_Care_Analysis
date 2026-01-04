-- Question 1: Monthly Encounters by Specialty
EXPLAIN ANALYZE
SELECT
  d.year,
  d.month,
  s.specialty_name,
  et.encounter_type_name,
  COUNT(*) AS total_encounters
FROM fact_encounters f
JOIN dim_date d ON f.date_key = d.date_key
JOIN dim_specialty s ON f.specialty_key = s.specialty_key
JOIN dim_encounter_type et ON f.encounter_type_key = et.encounter_type_key
GROUP BY d.year, d.month, s.specialty_name, et.encounter_type_name;

-- Question 2 Diagnosis–Procedure Pairs
EXPLAIN ANALYZE
SELECT
  bd.diagnosis_code,
  bp.procedure_code,
  COUNT(*) AS encounter_count
FROM bridge_encounter_diagnoses bd
JOIN bridge_encounter_procedures bp
  ON bd.encounter_key = bp.encounter_key
GROUP BY bd.diagnosis_code, bp.procedure_code;

-- Question 3 Readmission Rate
EXPLAIN ANALYZE
SELECT
  s.specialty_name,
  COUNT(*) AS readmissions
FROM fact_encounters f1
JOIN fact_encounters f2
  ON f1.patient_key = f2.patient_key
 AND f2.date_key BETWEEN f1.date_key AND f1.date_key + 30
JOIN dim_specialty s
  ON f1.specialty_key = s.specialty_key
WHERE f1.encounter_type_key = 2
GROUP BY s.specialty_name;

-- Question 4 Revenue by Specialty & Month
EXPLAIN ANALYZE
SELECT
  d.year,
  d.month,
  s.specialty_name,
  SUM(f.total_allowed_amount) AS revenue
FROM fact_encounters f
JOIN dim_date d ON f.date_key = d.date_key
JOIN dim_specialty s ON f.specialty_key = s.specialty_key
GROUP BY d.year, d.month, s.specialty_name;

SELECT COUNT(*) FROM fact_encounters;
