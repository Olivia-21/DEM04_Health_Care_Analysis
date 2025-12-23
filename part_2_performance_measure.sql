-- QUESTION 1 Monthly Encounters by Specialty
SELECT
    DATE_FORMAT(e.encounter_date ['%Y-%m']) AS encounter_mounth,
    s.specialty_name,
    e.encounter_type,
    COUNT(e.encounter_id) AS total_encounters,
    COUNT(DISTINCT e.encounter_id) AS unique_patients
FROM encounters e
JOIN providers p
ON e.provider_id = p.provider_id
JOIN departments d
ON p.department_id = d.department_id
JOIN specialties s
ON d.specialty_id = s.specialty_id

