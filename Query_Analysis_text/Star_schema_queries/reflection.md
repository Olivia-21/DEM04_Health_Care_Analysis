# Part 4: Analysis & Reflection

## Why Is the Star Schema Faster?

The star schema is significantly faster than the normalized OLTP schema because it is designed specifically for **analytical workloads**, not transactions. The performance improvement comes from fewer JOINs, pre-computed data, and denormalization.

### Reduced JOIN Complexity

In the normalized OLTP schema, analytical queries require long JOIN chains to connect related business concepts.

- Example (Revenue by Specialty):
  - OLTP JOIN chain: `billing → encounters → providers → specialties` (4 tables)

Each JOIN increases query cost by:
- Additional table scans  
- Larger intermediate result sets  
- More index lookups  

In the star schema with denormalization:
- Key attributes (specialty_name, encounter_type_name, date components) are stored directly in the fact table
- Queries like Q1, Q3, and Q4 require **ZERO JOINs** - they operate on the fact table alone

| Query | OLTP JOINs | Star Schema JOINs |
|-------|------------|-------------------|
| Q1    | 2          | 0                 |
| Q3    | 3          | 0                 |
| Q4    | 3          | 0                 |

Reducing JOINs dramatically lowers execution time because the database processes fewer tables and moves less data between them. This is the largest contributor to performance gains.

---

### Pre-Computed Data in the Star Schema

The star schema moves expensive calculations from **query time** to **ETL time**.

Examples of pre-computation:
- Date attributes (`year`, `month`, `month_name`) stored in `dim_date`
- Billing totals (`total_allowed_amount`) stored in `fact_encounters`
- Readmission logic stored as a boolean flag (`is_readmission`)

In the OLTP schema, these values must be computed during every query using functions such as `DATE_FORMAT()`, `DATEDIFF()`, or `SUM()` across large tables. These functions:
- Run once per row  
- Prevent index usage  
- Force full table scans  

By pre-computing them once during ETL, analytical queries become simple filters and aggregations over indexed columns.

---

### Why Denormalization Helps Analytical Queries

Denormalization intentionally duplicates small amounts of data to avoid repeated lookups.

For example:
- In OLTP, finding a provider’s specialty requires joining `providers → specialties`
- In the star schema, `specialty_name` is stored directly in `dim_provider`

This works well because:
- Dimension tables are small  
- The duplicated data is minimal  
- Eliminating JOINs saves significant execution time  

Denormalization favors **read performance**, which is exactly what analytical systems need.

---

## Trade-offs: What Did You Gain? What Did You Lose?

### What We Gained

- **Faster queries** (1.07–3.4× improvement on tested queries)
- **Simpler SQL**
  - Fewer JOINs  
  - No complex self-joins or date calculations  
- **Consistent business logic**
  - Metrics like revenue and readmissions are calculated once in ETL  
- **Better scalability**
  - Supports more users and more concurrent queries  

Overall, the star schema makes analytics faster, easier, and more reliable.

---

### What We Lost

- **Increased storage usage**
  - Data duplication in dimensions  
  - Pre-aggregated metrics stored in the fact table  
- **More complex ETL**
  - Dimension lookups  
  - Type 2 Slowly Changing Dimensions  
  - Handling late-arriving data  
- **Reduced data freshness**
  - Data is updated in batches, not real time  

These costs are acceptable because storage is cheap, ETL runs infrequently, and most analytical queries are historical.

**Verdict:** The trade-off is worth it.

---

## Bridge Tables: Worth It?

Diagnoses and procedures were kept in **bridge tables** instead of being denormalized into the fact table.

### Why Use Bridge Tables?

- Encounters can have **many diagnoses and many procedures**
- Denormalizing would cause **row explosion**
  - One encounter would be duplicated multiple times
- Most analytical queries do **not** need diagnosis-level detail

By using bridge tables:
- The fact table remains small and clean  
- Queries that don’t need diagnoses stay fast  
- Detailed analysis is still possible when needed  

---

### Trade-off

- Queries that analyze diagnoses and procedures (like Q2) require extra JOINs  
- These queries are slower than fact-only queries, but still faster than OLTP  

### Would This Change in Production?

Only if:
- Most queries required diagnosis-level detail, or  
- Diagnoses were 1:1 with encounters  

Given the workload, bridge tables are the better design choice.

---

## Performance Quantification

### Query 1: Monthly Encounters by Specialty

- **OLTP execution time:** 51.5ms (2 JOINs)
- **Star schema execution time:** ~35ms (0 JOINs)
- **Improvement:** 1.5× faster

**Main reason:**  
All grouping attributes (specialty_name, encounter_type_name, year, month) are denormalized into the fact table, eliminating all JOINs.

---

### Query 3: 30-Day Readmission Rate

- **OLTP execution time:** 51.1ms (3 JOINs: self-join + providers + specialties)
- **Star schema execution time:** 14.9ms (0 JOINs)
- **Improvement:** 3.4× faster

**Main reason:**  
The `is_readmission` flag is pre-computed during ETL, and `specialty_name` is denormalized into the fact table. The OLTP query requires an expensive self-join and date comparisons.

---

### Query 4: Revenue by Specialty & Month

- **OLTP execution time:** 85.5ms (3 JOINs)
- **Star schema execution time:** ~45ms (0 JOINs)
- **Improvement:** 1.9× faster

**Main reason:**  
`total_allowed_amount` is pre-aggregated, and `specialty_name` + date attributes are denormalized. The OLTP requires billing → encounters → providers → specialties chain.

---

## Final Takeaway

The star schema shifts computation from **query time** (executed thousands of times) to **ETL time** (executed once per load). For analytical workloads, this trade-off dramatically improves performance, simplifies analysis, and scales far better than a normalized OLTP design.
