import csv
import random
from datetime import datetime, timedelta

# -----------------------------
# Configuration
# -----------------------------
NUM_RECORDS = 10_000

PATIENT_ID_RANGE = (1, 5000)
PROVIDER_ID_RANGE = (1, 200)
DEPARTMENT_ID_RANGE = (1, 20)

ENCOUNTER_TYPES = ["Outpatient", "Inpatient", "ER"]

START_DATE = datetime(2019, 1, 1)
END_DATE = datetime(2025, 12, 31)

OUTPUT_FILE = "encounters.csv"


# -----------------------------
# Helper Functions
# -----------------------------
def random_date(start, end):
    """Generate a random date between start and end."""
    delta_days = (end - start).days
    return start + timedelta(days=random.randint(0, delta_days))


def format_date(dt):
    """Format date as YYYY-MM-DD (MySQL compatible)."""
    return dt.strftime("%Y-%m-%d")


def generate_discharge_date(encounter_type, encounter_date):
    """Generate discharge date based on encounter type."""
    if encounter_type == "Outpatient":
        return encounter_date
    elif encounter_type == "ER":
        return encounter_date + timedelta(days=random.choice([0, 1]))
    else:  # Inpatient
        return encounter_date + timedelta(days=random.randint(1, 14))


# -----------------------------
# Data Generation
# -----------------------------
with open(OUTPUT_FILE, mode="w", newline="", encoding="utf-8") as file:
    writer = csv.writer(file)

    # Header (exclude encounter_id because AUTO_INCREMENT)
    writer.writerow([
        "patient_id",
        "provider_id",
        "encounter_type",
        "encounter_date",
        "discharge_date",
        "department_id"
    ])

    for _ in range(NUM_RECORDS):
        patient_id = random.randint(*PATIENT_ID_RANGE)
        provider_id = random.randint(*PROVIDER_ID_RANGE)
        department_id = random.randint(*DEPARTMENT_ID_RANGE)

        encounter_type = random.choice(ENCOUNTER_TYPES)
        encounter_date = random_date(START_DATE, END_DATE)
        discharge_date = generate_discharge_date(encounter_type, encounter_date)

        writer.writerow([
            patient_id,
            provider_id,
            encounter_type,
            format_date(encounter_date),
            format_date(discharge_date),
            department_id
        ])

print(f"✅ {NUM_RECORDS} encounter records generated in '{OUTPUT_FILE}'")
