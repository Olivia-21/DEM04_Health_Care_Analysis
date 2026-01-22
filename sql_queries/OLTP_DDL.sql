-- Patient Table
CREATE TABLE patients (
  patient_id INT PRIMARY KEY AUTO_INCREMENT,
  first_name VARCHAR (100),
  last_name VARCHAR (100),
  date_of_birth DATE,
  gender CHAR(1),
  mrn VARCHAR (20) UNIQUE
);

-- Specialties Table
CREATE TABLE specialties (
  specialty_id INT PRIMARY KEY AUTO_INCREMENT,
  specialty_name VARCHAR(100),
  specialty_code VARCHAR (10)
);

-- Department Table
CREATE TABLE departments (
  department_id INT PRIMARY KEY AUTO_INCREMENT,
  department_name VARCHAR(100),
  floor INT,
  capacity INT  
);

-- Providers Table
CREATE TABLE providers (
  provider_id INT PRIMARY KEY AUTO_INCREMENT,
  first_name VARCHAR (100),
  last_name VARCHAR (100),
  credential VARCHAR(20),
  specialty_id INT,
  department_id INT,
  FOREIGN KEY (specialty_id) REFERENCES specialties (specialty_id),
  FOREIGN KEY (department_id) REFERENCES departments (department_id),
  INDEX idx_specialty_id (specialty_id),      -- For JOINs to specialties (Q1, Q3, Q4)
  INDEX idx_department_id (department_id)     -- For JOINs to departments
);

-- Encounters Table
CREATE TABLE encounters (
  encounter_id INT PRIMARY KEY AUTO_INCREMENT,
  patient_id INT,
  provider_id INT,
  encounter_type VARCHAR (50), -- 'Outpatient', 'Inpatient', 'ER'
  encounter_date DATETIME,
  discharge_date DATETIME,
  department_id INT,
  FOREIGN KEY (patient_id) REFERENCES patients (patient_id),
  FOREIGN KEY (provider_id) REFERENCES providers (provider_id),
  FOREIGN KEY (department_id) REFERENCES departments (department_id),
  INDEX idx_encounter_date (encounter_date),   -- For date filtering (Q1, Q4)
  INDEX idx_patient_id (patient_id),           -- For JOINs and readmission self-join (Q3)
  INDEX idx_provider_id (provider_id),         -- For JOINs to providers (Q1, Q3, Q4)
  INDEX idx_encounter_type (encounter_type),   -- For filtering Inpatient (Q3)
  INDEX idx_patient_discharge (patient_id, discharge_date)  -- Composite for readmission query (Q3)
);

-- Diagnoses Table
CREATE TABLE diagnoses (
  diagnosis_id INT PRIMARY KEY AUTO_INCREMENT,
  icd10_code VARCHAR(10),
  icd10_description VARCHAR(200)
);

-- Encounter diagnoses Table
CREATE TABLE encounter_diagnoses (
  encounter_diagnosis_id INT PRIMARY KEY AUTO_INCREMENT,
  encounter_id INT,
  diagnosis_id INT,
  diagnosis_sequence INT,
  FOREIGN KEY (encounter_id) REFERENCES encounters (encounter_id),
  FOREIGN KEY (diagnosis_id) REFERENCES diagnoses (diagnosis_id),
  INDEX idx_encounter_id (encounter_id),       -- For JOINs to encounters (Q2)
  INDEX idx_diagnosis_id (diagnosis_id)        -- For JOINs to diagnoses (Q2)
);

-- Procedures Table
CREATE TABLE procedures (
  procedure_id INT PRIMARY KEY AUTO_INCREMENT,
  cpt_code VARCHAR (10),
  cpt_description VARCHAR (200)
);

-- Encounter Procedures Table
CREATE TABLE encounter_procedures (
  encounter_procedure_id INT PRIMARY KEY AUTO_INCREMENT,
  encounter_id INT,
  procedure_id INT,
  procedure_date DATE,
  FOREIGN KEY (encounter_id) REFERENCES encounters (encounter_id),
  FOREIGN KEY (procedure_id) REFERENCES procedures (procedure_id),
  INDEX idx_encounter_id (encounter_id),       -- For JOINs to encounters (Q2)
  INDEX idx_procedure_id (procedure_id)        -- For JOINs to procedures (Q2)
);

-- Billing Table
CREATE TABLE billing (
  billing_id INT PRIMARY KEY AUTO_INCREMENT,
  encounter_id INT,
  claim_amount DECIMAL (12, 2),
  allowed_amount DECIMAL (12, 2),
  claim_date DATE,
  claim_status VARCHAR (50),
  FOREIGN KEY (encounter_id) REFERENCES encounters (encounter_id),
  INDEX idx_claim_date (claim_date),           -- For date filtering (Q4)
  INDEX idx_encounter_id (encounter_id)        -- For JOINs to encounters (Q4)
);



select * from encounter_procedures;


