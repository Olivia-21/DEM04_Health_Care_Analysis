# Part 4: Analysis & Reflection
git 
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

In the star schema:
- The fact table connects **directly** to all dimensions  
- The same query becomes: `fact_encounters → dim_date → dim_provider` (2 tables)

Reducing the number of JOINs lowers execution time because the database processes fewer tables and moves less data between them. This is one of the largest contributors to the performance gain.

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

- **Much faster queries** (5–20× improvement)
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

### Query 3: 30-Day Readmission Rate

- **OLTP execution time:** 4.5 seconds  
- **Star schema execution time:** 0.2 seconds  
- **Improvement:** 22.5× faster  

**Main reason:**  
The star schema eliminates an expensive self-join by using a pre-computed `is_readmission` flag.

---

### Query 4: Revenue by Specialty & Month

- **OLTP execution time:** 1.8 seconds  
- **Star schema execution time:** 0.18 seconds  
- **Improvement:** 10× faster  

**Main reason:**  
Billing totals are pre-aggregated in the fact table, eliminating the JOIN to the billing table and reducing aggregation cost.

---

## Final Takeaway

The star schema shifts computation from **query time** (executed thousands of times) to **ETL time** (executed once per load). For analytical workloads, this trade-off dramatically improves performance, simplifies analysis, and scales far better than a normalized OLTP design.
