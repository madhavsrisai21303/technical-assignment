# Technical Assignment

This repository contains solutions to the three Affinity Answers Full Stack Engineering technical-assignment questions. The implementations are intentionally small and explainable: a Python HTML scraper, three MySQL queries for the public Rfam database, and a Unix shell script that downloads and processes an S&P 500 constituents CSV.

## Repository layout

| Path | Purpose |
| --- | --- |
| `question1/scraper.py` | Accepts a search term and prints MDComputers product names and selling prices. |
| `question2/queries.sql` | Contains the three requested Rfam SQL queries, with comments and explicit joins. |
| `question3/companies.sh` | Downloads a CSV URL, extracts company fields, sorts by founding year, and prints a table. |

## Prerequisites and dependencies

Python 3.9 or newer is required for Question 1. Install its two third-party packages with:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
```

Question 2 requires a MySQL-compatible client or SQL editor. The queries target the read-only Rfam public database documented by Rfam [1]. Question 3 requires Bash, `curl`, `sort`, `awk`, and Python 3; these are normally available on Unix/Linux systems. No external package is required for Question 3 because its CSV parsing uses Python's standard library.

## Question 1: Python web scraping

Run interactively:

```bash
python3 question1/scraper.py
Enter search term: external hard drive
```

A term may also be supplied as a command-line argument:

```bash
python3 question1/scraper.py "external hard drive"
```

The program URL-encodes the input, requests the MDComputers search route, parses product cards with BeautifulSoup, and prints a numbered table. It handles an empty term, request failures, non-success HTTP responses, and pages with no matching products. The parser has selector fallbacks because retail-site markup can change.

Example output shape:

```text
Search results for: external hard drive
================================================================================
  #  Product name                                                  Selling price
--------------------------------------------------------------------------------
  1  SanDisk E61 Extreme 1TB Portable SSD                         ₹16,499
```

The site may return a Cloudflare challenge or HTTP 403 to automated clients. This is an external-site limitation rather than a parser failure; the program reports the request error instead of silently returning misleading data.

## Question 2: SQL and database

The three queries are in `question2/queries.sql`, in the same order as the assignment. Connect using the public Rfam settings from the official documentation [1], then execute the file in a MySQL client:

```bash
mysql --user rfamro \
  --host mysql-rfam-public.ebi.ac.uk \
  --port 4497 \
  --database Rfam < question2/queries.sql
```

The queries use the following relationships: `taxonomy.ncbi_id = rfamseq.ncbi_id`, `full_region.rfamseq_acc = rfamseq.rfamseq_acc`, and `full_region.rfam_acc = family.rfam_acc`. Query C calculates one maximum sequence length per family before applying page 9 pagination with `LIMIT 120, 15`. A stable accession tie-breaker is included after the required descending length sort.

The interpretation used for Query A is the number of taxonomy records whose lineage string contains `Acacia`. Query B searches both the common word `wheat` and the scientific genus `Triticum`; this avoids depending on only one naming convention in the taxonomy strings. These choices are stated in the SQL comments so they can be adjusted easily if the evaluator defines “type” or “wheat” more narrowly.

## Question 3: Unix shell scripting

Make the script executable and pass the dataset URL as its only argument:

```bash
chmod +x question3/companies.sh
./question3/companies.sh "DATASET_URL"
```

The URL is never hard-coded. The script downloads it with `curl --fail --location`, stores it in a temporary file, and removes that file automatically. The embedded standard-library CSV parser correctly handles quoted commas such as `"New York, NY"`, identifies columns by header name, emits `N/A` for a missing founding year, and uses Unix `sort` to order the results chronologically (unknown years last).

## Verification and limitations

The Python parser was checked with duplicate cards, multiple products, and an empty result page. The shell script was checked with a local CSV fixture containing quoted commas, sorted years, a missing year, a missing argument, and shell syntax validation. Query C follows MySQL pagination syntax and should be run against the specific Rfam release available at execution time; data-dependent result values can change as Rfam is updated.

The scraper depends on the current MDComputers search route and public HTML structure. The shell script assumes the CSV has a header containing recognizable variants of security/company name, headquarters/location, and founded/founding-year fields. It intentionally fails with a useful error if those columns are absent instead of guessing column positions.

## References

[1]: https://docs.rfam.org/en/latest/database.html "Rfam: Public MySQL Database"

[2]: https://mdcomputers.in/ "MDComputers.in"
