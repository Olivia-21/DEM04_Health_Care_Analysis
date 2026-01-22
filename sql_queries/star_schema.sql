-- ======================
-- Date Dimension
-- ======================
CREATE TABLE dim_date (
  date_key INT PRIMARY KEY,
  calendar_date DATE NOT NULL,
  year INT,
  month INT,
  month_name VARCHAR(20),
  quarter INT,
  day INT,
  day_of_week VARCHAR(10)
);


-- ======================
-- Patient Dimension (SCD Type 2)
-- ======================
CREATE TABLE dim_patient (
  patient_key INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,                      -- Natural key (not unique - multiple versions)
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  gender CHAR(1),
  date_of_birth DATE,
  age INT,
  age_group VARCHAR(20),
  mrn VARCHAR(20),
  
  -- SCD Type 2 Columns (for tracking historical changes)
  effective_start_date DATE NOT NULL,           -- When this version became active
  effective_end_date DATE DEFAULT NULL,         -- When this version expired (NULL = current)
  is_current BOOLEAN DEFAULT TRUE,              -- Quick filter for current version
  
  INDEX idx_patient_id (patient_id),
  INDEX idx_is_current (is_current),
  INDEX idx_patient_current (patient_id, is_current)  -- Composite for lookups
);

-- ======================
-- Specialty Dimension
-- ======================
CREATE TABLE dim_specialty (
  specialty_key INT PRIMARY KEY AUTO_INCREMENT,
  specialty_id INT NOT NULL,
  specialty_name VARCHAR(100),
  specialty_code VARCHAR(10), 
  INDEX idx_specialty_id (specialty_id)
);

-- ======================
-- Department Dimension
-- ======================
CREATE TABLE dim_department (
  department_key INT AUTO_INCREMENT PRIMARY KEY,
  department_id INT NOT NULL UNIQUE,
  department_name VARCHAR(100),
  floor INT, 
  capacity INT,
  INDEX idx_department_id (department_id)
);


-- ======================
-- Provider Dimension (SCD Type 2)
-- ======================
CREATE TABLE dim_provider (
  provider_key INT AUTO_INCREMENT PRIMARY KEY,
  provider_id INT NOT NULL,                     -- Natural key (not unique - multiple versions)
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  credential VARCHAR(20),
  specialty_id INT,
  specialty_name VARCHAR(100),
  specialty_code VARCHAR(10),
  department_id INT,
  department_name VARCHAR(100),
  
  -- SCD Type 2 Columns (for tracking historical changes)
  effective_start_date DATE NOT NULL,           -- When this version became active
  effective_end_date DATE DEFAULT NULL,         -- When this version expired (NULL = current)
  is_current BOOLEAN DEFAULT TRUE,              -- Quick filter for current version
  
  INDEX idx_provider_id (provider_id),
  INDEX idx_specialty_name (specialty_name),
  INDEX idx_is_current (is_current),
  INDEX idx_provider_current (provider_id, is_current)  -- Composite for lookups
);

-- =========================
-- Diagnosis Dimension
-- =========================
CREATE TABLE dim_diagnosis (
    diagnosis_key INT PRIMARY KEY AUTO_INCREMENT,
    diagnosis_id INT NOT NULL UNIQUE,
    icd10_code VARCHAR(10) NOT NULL,
    icd10_description VARCHAR(200),
    INDEX idx_diagnosis_id (diagnosis_id),
    INDEX idx_icd10_code (icd10_code)
);

-- =========================
-- Procedure Dimension
-- =========================
CREATE TABLE dim_procedure (
    procedure_key INT PRIMARY KEY AUTO_INCREMENT,
    procedure_id INT NOT NULL UNIQUE,
    cpt_code VARCHAR(10) NOT NULL,
    cpt_description VARCHAR(200),
    INDEX idx_procedure_id (procedure_id),
    INDEX idx_cpt_code (cpt_code)
);


-- ======================
-- Encounter Type Dimension
-- ======================
CREATE TABLE dim_encounter_type (
  encounter_type_key INT AUTO_INCREMENT PRIMARY KEY,
  encounter_type_name VARCHAR(50) NOT NULL UNIQUE, 
  INDEX idx_type_name (encounter_type_name)
);


-- ======================
-- Fact Table
-- ======================
CREATE TABLE fact_encounters (
    encounter_key INT PRIMARY KEY AUTO_INCREMENT,
    encounter_id INT NOT NULL UNIQUE,
    
    -- Foreign Keys to Dimensions
    encounter_date_key INT NOT NULL,
    discharge_date_key INT,
    patient_key INT NOT NULL,
    provider_key INT NOT NULL,
    specialty_key INT NOT NULL,
    department_key INT NOT NULL,
    encounter_type_key INT NOT NULL,
    
    -- Encounter Details
    encounter_date DATETIME NOT NULL,
    discharge_date DATETIME,
    length_of_stay_days INT,
    
    -- Denormalized Attributes (to eliminate JOINs in analytical queries)
    specialty_name VARCHAR(100),          -- From dim_provider/dim_specialty
    encounter_type_name VARCHAR(50),      -- From dim_encounter_type
    encounter_year INT,                   -- From dim_date
    encounter_month INT,                  -- From dim_date
    encounter_month_name VARCHAR(20),     -- From dim_date
    
    -- Pre-aggregated Metrics (to avoid expensive JOINs)
    diagnosis_count INT DEFAULT 0,
    procedure_count INT DEFAULT 0,
    
    -- Financial Metrics (pre-aggregated from billing)
    total_claim_amount DECIMAL(12, 2) DEFAULT 0,
    total_allowed_amount DECIMAL(12, 2) DEFAULT 0,
    billing_count INT DEFAULT 0,
    
    -- Readmission Analysis Helper
    is_inpatient BOOLEAN,
    previous_discharge_date DATETIME,
    is_readmission BOOLEAN DEFAULT FALSE,
    days_since_last_discharge INT,
    
    -- Foreign Key Constraints
    FOREIGN KEY (encounter_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (discharge_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (provider_key) REFERENCES dim_provider(provider_key),
    FOREIGN KEY (specialty_key) REFERENCES dim_specialty(specialty_key),
    FOREIGN KEY (department_key) REFERENCES dim_department(department_key),
    FOREIGN KEY (encounter_type_key) REFERENCES dim_encounter_type(encounter_type_key),
    
    -- Indexes for Performance
    INDEX idx_encounter_id (encounter_id),
    INDEX idx_encounter_date_key (encounter_date_key),
    INDEX idx_patient_key (patient_key),
    INDEX idx_provider_key (provider_key),
    INDEX idx_specialty_key (specialty_key),
    INDEX idx_encounter_type_key (encounter_type_key),
    INDEX idx_readmission (is_readmission, specialty_key),
    INDEX idx_date_specialty (encounter_date_key, specialty_key),
    INDEX idx_patient_encounter_date (patient_key, encounter_date),
    
    -- Indexes for Denormalized Columns (used in optimized queries)
    INDEX idx_specialty_name (specialty_name),                    -- Q1, Q3, Q4 GROUP BY
    INDEX idx_encounter_type_name (encounter_type_name),          -- Q1 GROUP BY
    INDEX idx_year_month (encounter_year, encounter_month),       -- Q1, Q4 GROUP BY
    INDEX idx_is_inpatient (is_inpatient)                         -- Q3 WHERE filter
);


-- ======================
-- Bridge Tables
-- ======================

CREATE TABLE bridge_encounter_diagnoses (
    bridge_diagnosis_key INT PRIMARY KEY AUTO_INCREMENT,
    encounter_key INT NOT NULL,
    diagnosis_key INT NOT NULL,
    diagnosis_sequence INT, -- Primary, Secondary, etc.
    
    FOREIGN KEY (encounter_key) REFERENCES fact_encounters(encounter_key),
    FOREIGN KEY (diagnosis_key) REFERENCES dim_diagnosis(diagnosis_key),
    
    INDEX idx_encounter_key (encounter_key),
    INDEX idx_diagnosis_key (diagnosis_key),
    INDEX idx_encounter_diagnosis (encounter_key, diagnosis_key),
    
    UNIQUE KEY uk_encounter_diagnosis_seq (encounter_key, diagnosis_key, diagnosis_sequence)
);

-- Bridge: Encounter to Procedures (preserves many-to-many relationship)
CREATE TABLE bridge_encounter_procedures (
    bridge_procedure_key INT PRIMARY KEY AUTO_INCREMENT,
    encounter_key INT NOT NULL,
    procedure_key INT NOT NULL,
    procedure_date DATE,
    
    FOREIGN KEY (encounter_key) REFERENCES fact_encounters(encounter_key),
    FOREIGN KEY (procedure_key) REFERENCES dim_procedure(procedure_key),
    
    INDEX idx_encounter_key (encounter_key),
    INDEX idx_procedure_key (procedure_key),
    INDEX idx_encounter_procedure (encounter_key, procedure_key),
    
    UNIQUE KEY uk_encounter_procedure (encounter_key, procedure_key, procedure_date)
);






