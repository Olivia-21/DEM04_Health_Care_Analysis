# DEM04 Health Care Analysis — OLTP to Star Schema (Performance Lab)

## Overview
This lab models a simplified **health-care operational database (OLTP)** and then redesigns it into an **analytics-optimized Star Schema**. The goal is to compare query performance and complexity for common analytical questions when run on:

- **Normalized OLTP tables** (transactional design; more JOINs at query time)
- **Star Schema** (denormalized fact/dim design; fewer JOINs + pre-computed metrics)

The repo includes:
- OLTP DDL (with indexes)
- Star schema DDL (fact table + dimensions + bridge tables)
- An ETL load script (SQL) to populate the star schema from OLTP tables
- Written query analysis + design decisions + reflection

## Business Questions 
The lab evaluates these four analytics-style questions in both schemas:

1. **Monthly encounters by specialty** (encounters + unique patients)
2. **Top diagnosis–procedure pairs**
3. **30-day readmission rate** (by specialty)
4. **Revenue by specialty and month**


## Repository Structure
- **`Data/`**: Source CSV files (patients, providers, encounters, billing, diagnoses, procedures, and bridge/fact exports)
- **`sql_queries/`**:
  - `OLTP_DDL.sql`: OLTP schema (tables + indexes)
  - `star_schema.sql`: Star schema (dimensions + fact + bridge tables)
  - `DML_star_schema.sql`: ETL load (OLTP → Star), in dependency order
  - `OLTP_performance_measure.sql`: OLTP benchmark queries (`EXPLAIN ANALYZE`)
  - `star_schema_performance_measure.sql`: Star schema benchmark queries (`EXPLAIN ANALYZE`)
- **`Query_Analysis_text/`**:
  - `OLTP_query_analysis/query_analysis.txt`: OLTP query bottlenecks + root-cause discussion
  - `Star_schema_queries/design_decisions.txt`: grain, denormalization, bridge tables, pre-aggregation rationale
  - `Star_schema_queries/etl_design.txt`: ETL approach & SCD/refresh strategy (design-level)
  - `Star_schema_queries/star_schema_queries.txt`: star schema SQL + analysis
  - `Star_schema_queries/reflection.md`: written reflection on trade-offs and performance
- **Diagrams**:
  - `OLTP_Schema_Diagram.png`
  - `Star_Schema_Diagram.png`




### 1) Create the OLTP schema
1. Create a database (example: `healthcare_oltp`).
2. Run:
   - `sql_queries/OLTP_DDL.sql`

### 2) Load OLTP data from CSVs
Load the CSVs from `Data/` into their matching OLTP tables. You can do this via:
- MySQL Workbench “Table Data Import Wizard”, or
- `LOAD DATA INFILE` (if your MySQL configuration allows it).

Typical load order (high level):
- `patients`, `specialties`, `departments`
- `providers` (depends on specialties/departments)
- `encounters` (depends on patients/providers/departments)
- `diagnoses`, `procedures`
- `encounter_diagnoses`, `encounter_procedures` (depend on encounters + diagnoses/procedures)
- `billing` (depends on encounters)

### 3) Run OLTP benchmark queries
Run:
- `sql_queries/OLTP_performance_measure.sql`

This uses `EXPLAIN ANALYZE` for the four questions and reflects typical OLTP bottlenecks (JOIN chains, GROUP BY sorts, self-joins for readmissions, etc.). Detailed notes are in:
- `Query_Analysis_text/OLTP_query_analysis/query_analysis.txt`

### 4) Create the Star Schema
Create a second database (example: `healthcare_dw`) or use a separate schema.
Run:
- `sql_queries/star_schema.sql`

### 5) Run ETL (OLTP → Star)
Run:
- `sql_queries/DML_star_schema.sql`

This script loads in dependency order:
- **Dimensions first** (`dim_date`, `dim_specialty`, `dim_department`, `dim_encounter_type`, `dim_diagnosis`, `dim_procedure`, `dim_patient`)
- **Then dependent dimensions** (`dim_provider`)
- **Then the fact table** (`fact_encounters`) with denormalized attributes + pre-aggregated metrics
- **Then bridge tables** (`bridge_encounter_diagnoses`, `bridge_encounter_procedures`)

ETL design notes (including SCD Type 2 intent) are in:
- `Query_Analysis_text/Star_schema_queries/etl_design.txt`

### 6) Run Star Schema benchmark queries
Run:
- `sql_queries/star_schema_performance_measure.sql`

The star schema is designed so that Q1/Q3/Q4 can run with **0 JOINs** (fact-only queries) due to:
- Denormalized attributes in `fact_encounters` (e.g., `specialty_name`, `encounter_year/month`)
- Pre-computed metrics (`total_allowed_amount`, `is_readmission`, counts)

## Star Schema Design Highlights
- **Fact grain**: one row per encounter (`fact_encounters`)
- **SCD Type 2**: dimensions such as `dim_patient` and `dim_provider` include effective dates and `is_current`
- **Bridge tables**: preserve many-to-many relationships for diagnoses and procedures without exploding fact rows:
  - `bridge_encounter_diagnoses`
  - `bridge_encounter_procedures`
- **Denormalization + pre-aggregation**: reduces JOINs and shifts compute cost from query-time to ETL-time

Full rationale is documented in:
- `Query_Analysis_text/Star_schema_queries/design_decisions.txt`

## Reflection / Write-up
The reflection and trade-off discussion is in:
- `Query_Analysis_text/Star_schema_queries/reflection.md`



