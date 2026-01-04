-- ======================
-- Date Dimension
-- ======================
CREATE TABLE dim_date (
  date_key INT PRIMARY KEY,
  calendar_date DATE,
  year INT,
  month INT,
  month_name VARCHAR(20),
  quarter INT,
  day_of_month INT,
  day_of_week VARCHAR(10)
);


-- ======================
-- Patient Dimension
-- ======================
CREATE TABLE dim_patient (
  patient_key INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  gender CHAR(1),
  date_of_birth DATE,
  age INT,
  age_group VARCHAR(20)
);

-- ======================
-- Specialty Dimension
-- ======================
CREATE TABLE dim_specialty (
  specialty_key INT PRIMARY KEY AUTO_INCREMENT,
  specialty_id INT,
  specialty_name VARCHAR(100),
  specialty_code VARCHAR(10)
);

-- ======================
-- Department Dimension
-- ======================
CREATE TABLE dim_department (
  department_key INT AUTO_INCREMENT PRIMARY KEY,
  department_id INT,
  department_name VARCHAR(100),
  floor INT
);

-- ======================
-- Provider Dimension
-- ======================
CREATE TABLE dim_provider (
  provider_key INT AUTO_INCREMENT PRIMARY KEY,
  provider_id INT,
  provider_name VARCHAR(200),
  credential VARCHAR(20),
  specialty_key INT,
  department_key INT
);

-- ======================
-- Encounter Type Dimension
-- ======================
CREATE TABLE dim_encounter_type (
  encounter_type_key INT AUTO_INCREMENT PRIMARY KEY,
  encounter_type_name VARCHAR(50)
);

-- ======================
-- Fact Table
-- ======================
CREATE TABLE fact_encounters (
  encounter_key INT AUTO_INCREMENT PRIMARY KEY,
  encounter_id INT,
  date_key INT,
  patient_key INT,
  provider_key INT,
  specialty_key INT,
  department_key INT,
  encounter_type_key INT,
  diagnosis_count INT,
  procedure_count INT,
  total_claim_amount DECIMAL(12,2),
  total_allowed_amount DECIMAL(12,2),
  length_of_stay_days INT,
  INDEX idx_date (date_key),
  INDEX idx_specialty (specialty_key)
);

-- ======================
-- Bridge Tables
-- ======================
CREATE TABLE bridge_encounter_diagnoses (
  encounter_key INT,
  diagnosis_code VARCHAR(10)
);

CREATE TABLE bridge_encounter_procedures (
  encounter_key INT,
  procedure_code VARCHAR(10)
);

