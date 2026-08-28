#!/usr/bin/env bash
# Download an S&P 500 constituents CSV and print company, location, and founding year.

set -euo pipefail

if [[ $# -ne 1 || -z "${1//[[:space:]]/}" ]]; then
    printf 'Usage: %s DATASET_URL\n' "$0" >&2
    exit 2
fi

dataset_url=$1
temporary_csv=$(mktemp)
trap 'rm -f "$temporary_csv"' EXIT

if ! curl --fail --location --silent --show-error --max-time 60 \
    --output "$temporary_csv" "$dataset_url"; then
    printf 'Error: failed to retrieve CSV from %s\n' "$dataset_url" >&2
    exit 1
fi

if [[ ! -s "$temporary_csv" ]]; then
    printf 'Error: downloaded CSV is empty.\n' >&2
    exit 1
fi

# Python's standard csv module correctly handles quoted commas in locations.
# It emits a sortable year column first; unknown years are placed last.
python3 - "$temporary_csv" <<'PY' | LC_ALL=C sort -t $'\t' -k1,1n -k2,2f | awk -F '\t' 'BEGIN { printf "%-45s %-35s %s\n", "Company", "Location", "Founding year"; printf "%s\n", "---------------------------------------------------------------------------------------------------------------" } { printf "%-45s %-35s %s\n", $2, $3, $4 }'
import csv
import re
import sys

csv_path = sys.argv[1]

def normalized(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())

def find_column(headers: list[str], candidates: tuple[str, ...]) -> int:
    normalized_headers = [normalized(header) for header in headers]
    for candidate in candidates:
        candidate_normalized = normalized(candidate)
        if candidate_normalized in normalized_headers:
            return normalized_headers.index(candidate_normalized)
    raise ValueError(f"none of the expected columns found: {', '.join(candidates)}")

try:
    with open(csv_path, newline="", encoding="utf-8-sig") as input_file:
        reader = csv.reader(input_file)
        headers = next(reader, None)
        if not headers:
            raise ValueError("CSV has no header row")

        name_index = find_column(headers, ("Security", "Company", "Name"))
        location_index = find_column(headers, ("Headquarters Location", "Location"))
        founded_index = find_column(headers, ("Founded", "Founding Year", "Year Founded"))

        for row in reader:
            if len(row) <= max(name_index, location_index, founded_index):
                continue
            name = row[name_index].strip()
            location = row[location_index].strip()
            founded = row[founded_index].strip()
            year_match = re.search(r"\b(1[5-9]\d{2}|20\d{2})\b", founded)
            year = year_match.group(1) if year_match else "N/A"
            sortable_year = year if year != "N/A" else "999999999"
            print("\t".join((sortable_year, name, location, year)))
except (OSError, StopIteration, ValueError) as error:
    print(f"Error: unable to process CSV ({error}).", file=sys.stderr)
    sys.exit(1)
PY
