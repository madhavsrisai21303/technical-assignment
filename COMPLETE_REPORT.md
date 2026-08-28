# Complete Technical Assignment Report

## 1. Executive summary

The assignment required three independent solutions: a Python web scraper for MDComputers, SQL queries against the public Rfam MySQL database, and a Unix shell script for processing an S&P 500 companies CSV file. I implemented all three solutions in one GitHub repository and documented the setup, execution commands, assumptions, error handling, and limitations.

The repository is available at:

> [https://github.com/madhavsrisai21303/technical-assignment](https://github.com/madhavsrisai21303/technical-assignment)

It is a private repository on the `main` branch. The repository has four meaningful commits rather than one unexplained upload. A downloadable archive was also prepared separately.

## 2. Repository structure

```text
technical-assignment/
├── README.md
├── COMPLETE_REPORT.md
├── requirements.txt
├── .gitignore
├── question1/
│   └── scraper.py
├── question2/
│   └── queries.sql
└── question3/
    └── companies.sh
```

| File | Responsibility |
| --- | --- |
| `README.md` | Concise setup, execution, examples, dependencies, assumptions, and limitations. |
| `requirements.txt` | Python dependencies: `requests` and `beautifulsoup4`. |
| `question1/scraper.py` | Accepts a search term, requests MDComputers, parses product cards, and prints names and prices. |
| `question2/queries.sql` | Contains Questions 2A, 2B, and 2C with comments and joins. |
| `question3/companies.sh` | Downloads a CSV URL, extracts fields, sorts records, and prints a formatted table. |
| `.gitignore` | Excludes virtual environments, Python cache files, and local operating-system files. |

The Git history is:

| Commit | Meaning |
| --- | --- |
| `179b1ab` | Added the MDComputers product scraper. |
| `b76b1af` | Added the Rfam SQL queries. |
| `d160cb0` | Added the company CSV processing shell script. |
| `fbad0e4` | Added documentation, setup information, assumptions, and repository hygiene files. |

## 3. General setup

Clone the repository and enter its directory:

```bash
git clone https://github.com/madhavsrisai21303/technical-assignment.git
cd technical-assignment
```

Question 1 requires Python and two third-party packages. A virtual environment keeps these packages isolated from the system Python installation:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
```

The shell solution needs Bash, `curl`, `sort`, `awk`, and Python 3. Question 2 requires a MySQL-compatible client. On Ubuntu, a MySQL client can be installed with:

```bash
sudo apt-get update
sudo apt-get install -y mysql-client
```

The Rfam documentation lists the public read-only connection as host `mysql-rfam-public.ebi.ac.uk`, port `4497`, user `rfamro`, database `Rfam`, with no password [1].

## 4. Question 1: Python web scraping

### 4.1 What the program must do

The program accepts a product search term such as `external hard drive`, builds the MDComputers search URL, downloads the HTML, parses the search results, extracts each product name and selling price, and displays the results in a readable table.

The search term is not hard-coded. It can be entered interactively or supplied as a command-line argument.

### 4.2 How to run it

Interactive mode:

```bash
python3 question1/scraper.py
```

The program prompts:

```text
Enter search term:
```

Enter a value such as:

```text
external hard drive
```

Command-line mode:

```bash
python3 question1/scraper.py "external hard drive"
```

The command-line form is especially useful in scripts and demonstrations because it avoids interactive input.

### 4.3 URL construction

The program uses these constants:

```python
BASE_URL = "https://mdcomputers.in"
SEARCH_PATH = "/index.php?route=product/search&search="
```

The function `build_search_url()` strips leading and trailing whitespace and applies `quote_plus()` to the user’s input. For example:

```text
external hard drive
```

becomes:

```text
https://mdcomputers.in/index.php?route=product/search&search=external+hard+drive
```

URL encoding is important because spaces and special characters should not be inserted into a URL raw. It also allows terms such as `SSD 1TB` or `Kingston & Corsair` to be represented safely.

### 4.4 Data model

The `Product` dataclass stores the two required fields:

```python
@dataclass(frozen=True)
class Product:
    name: str
    price: str
```

This makes the data clear and avoids passing loosely structured dictionaries throughout the program. `frozen=True` makes each result immutable after creation.

### 4.5 HTML parsing

The program uses `requests` for HTTP and `BeautifulSoup` for HTML parsing. It first looks for common product-card selectors:

```python
cards = soup.select(".product-layout, .product-thumb, .product-grid-item")
```

Within each card it searches for product-name and price selectors:

```python
name_element = card.select_one(
    ".caption h4 a, .caption .name a, h4 a, .product-name a"
)
price_element = card.select_one(
    ".price-new, .price, .product-price"
)
```

The selector list is deliberately small but includes fallbacks. Retail websites sometimes change CSS class names or use more than one template. The helper `_text()` removes extra whitespace and returns clean text.

If no products were found through the card selectors, the scraper performs a second fallback by looking for product links containing `/product/` and searching their parent container for a price. This makes the parser somewhat more tolerant of variations in the page structure.

Duplicate product cards are removed while preserving page order. Some pages show the same product in multiple carousel or responsive sections. A set of `(name, price)` pairs is used to identify duplicates.

### 4.6 HTTP and input error handling

`requests.get()` uses a timeout and a descriptive user-agent:

```python
response = requests.get(
    url,
    headers={"User-Agent": USER_AGENT},
    timeout=timeout,
)
response.raise_for_status()
```

The timeout prevents the program from waiting indefinitely. `raise_for_status()` turns HTTP errors such as 403 or 500 into exceptions. The main function catches `RequestException` and prints an understandable error to standard error.

The program also handles an empty search term and returns exit code `2` for invalid input. A network or HTTP failure returns exit code `1`. A valid request with no products is not treated as a crash; it prints:

```text
No products found.
```

### 4.7 Example output

The exact products and prices depend on the live site, but the output format is:

```text
Search results for: external hard drive
================================================================================
  #  Product name                                                  Selling price
--------------------------------------------------------------------------------
  1  SanDisk E61 Extreme 1TB Portable SSD                         ₹16,499
```

### 4.8 Important limitation

The MDComputers website may return a Cloudflare challenge or HTTP 403 to automated clients. The scraper does not attempt to bypass that protection. It reports the request failure clearly. This is preferable to returning incomplete or fabricated results. The URL route was confirmed from the site’s search form as:

```text
/index.php?route=product/search&search=
```

## 5. Question 2: SQL and Rfam

### 5.1 Database relationships

The Rfam documentation identifies the relevant tables and relationships [1]. The submitted queries use these joins:

| Relationship | Meaning |
| --- | --- |
| `taxonomy.ncbi_id = rfamseq.ncbi_id` | Associates a sequence with its NCBI taxonomy record. |
| `full_region.rfamseq_acc = rfamseq.rfamseq_acc` | Associates a family-region annotation with its sequence. |
| `full_region.rfam_acc = family.rfam_acc` | Associates an annotated region with its Rfam family. |

The public database can be queried with:

```bash
mysql --user rfamro \
  --host mysql-rfam-public.ebi.ac.uk \
  --port 4497 \
  --database Rfam < question2/queries.sql
```

The queries are separated by comments in `question2/queries.sql`, so they can be executed together or copied individually into a SQL editor.

### 5.2 Query 2A: count Acacia taxonomy types

The query is:

```sql
SELECT COUNT(*) AS acacia_taxonomy_types
FROM taxonomy AS t
WHERE t.tax_string LIKE '%Acacia%';
```

The `taxonomy` table is the correct table because the question asks how many types are present in taxonomy, not how many DNA sequences or Rfam annotations match. `tax_string` contains the taxonomic lineage/name text. The wildcard pattern finds records where `Acacia` appears anywhere in that string.

The alias `acacia_taxonomy_types` gives the result a clear column name. `COUNT(*)` returns one row containing the count.

The interpretation used here is “number of taxonomy records whose taxonomy string contains Acacia.” If the evaluator defines “type” as a distinct text value rather than a taxonomy record, the query could be changed to:

```sql
SELECT COUNT(DISTINCT t.tax_string) AS acacia_taxonomy_types
FROM taxonomy AS t
WHERE t.tax_string LIKE '%Acacia%';
```

The submitted version follows the direct interpretation of counting matching taxonomy entries and explains that assumption in comments.

### 5.3 Query 2B: longest wheat sequence

The query is:

```sql
SELECT
    t.tax_string AS wheat_type,
    r.length AS dna_sequence_length
FROM rfamseq AS r
JOIN taxonomy AS t
    ON t.ncbi_id = r.ncbi_id
WHERE LOWER(t.tax_string) LIKE '%wheat%'
   OR LOWER(t.tax_string) LIKE '%triticum%'
ORDER BY r.length DESC
LIMIT 1;
```

The sequence table `rfamseq` contains the sequence length. The taxonomy table supplies the type or taxonomic description. The join is necessary because the sequence row and taxonomy description are stored separately and share `ncbi_id`.

`LOWER()` makes the search intention explicit and avoids relying on the database collation. The query checks both the common name `wheat` and the scientific genus `Triticum`. This is useful because biological taxonomy may use either common or scientific naming.

`ORDER BY r.length DESC` puts the longest sequence first. `LIMIT 1` returns only that row. The output columns are named `wheat_type` and `dna_sequence_length`, which directly describe the answer.

If the evaluator wants only one naming convention, the `WHERE` clause can be narrowed. For example, for only scientific wheat records:

```sql
WHERE LOWER(t.tax_string) LIKE '%triticum%'
```

### 5.4 Query 2C: page 9 of large families

The query is:

```sql
SELECT
    f.rfam_acc AS family_accession,
    f.rfam_id AS family_name,
    MAX(r.length) AS maximum_dna_sequence_length
FROM family AS f
JOIN full_region AS fr
    ON fr.rfam_acc = f.rfam_acc
JOIN rfamseq AS r
    ON r.rfamseq_acc = fr.rfamseq_acc
GROUP BY
    f.rfam_acc,
    f.rfam_id
HAVING MAX(r.length) > 1000000
ORDER BY maximum_dna_sequence_length DESC, family_accession ASC
LIMIT 120, 15;
```

The query proceeds logically as follows:

1. Start with Rfam families.
2. Join each family to its annotated regions in `full_region`.
3. Join each region to the corresponding sequence in `rfamseq`.
4. Group rows by family accession and family name.
5. Calculate the maximum sequence length per family.
6. Keep only families whose maximum is greater than `1,000,000`.
7. Sort from longest maximum sequence to shortest.
8. Return rows 121 through 135.

The `MAX()` aggregation is important because one family can be associated with many sequences. The result must contain one row per family, not one row per region or sequence.

The `HAVING` clause is used rather than `WHERE` because the filter applies to an aggregate expression, `MAX(r.length)`. `WHERE` operates before grouping, while `HAVING` operates after grouping.

Page 9 contains rows 121–135. MySQL’s `LIMIT offset, row_count` syntax is zero-based for the offset, so:

```text
(page - 1) × page_size = (9 - 1) × 15 = 120
```

Therefore:

```sql
LIMIT 120, 15
```

The secondary sort by accession makes the order deterministic when two families have the same maximum length. The primary required ordering remains descending sequence length.

### 5.5 SQL assumptions and data freshness

The Rfam public database is updated with Rfam releases, so data-dependent counts and returned rows may change over time [1]. The SQL structure remains the same, but the exact results should be generated against the database release available when the evaluator runs the queries.

The queries use the column names described in the assignment and Rfam documentation, especially `tax_string`, `ncbi_id`, `rfamseq_acc`, `rfam_acc`, `rfam_id`, and `length`. If a particular release exposes a slightly different family-name column, the family-name expression should be checked with `DESCRIBE family;` and adjusted.

## 6. Question 3: Unix shell scripting

### 6.1 How to run it

Make the script executable:

```bash
chmod +x question3/companies.sh
```

Then pass the dataset URL as the only argument:

```bash
./question3/companies.sh "DATASET_URL"
```

The URL is supplied by the caller and is not hard-coded in the script. This satisfies the assignment requirement and lets the same program work with different compatible CSV sources.

### 6.2 Strict shell behavior

The script begins with:

```bash
set -euo pipefail
```

This provides three protections:

| Setting | Effect |
| --- | --- |
| `-e` | Stops when a command fails instead of silently continuing. |
| `-u` | Treats an unset variable as an error. |
| `pipefail` | Makes a pipeline fail if an earlier command in the pipeline fails. |

The script checks that exactly one non-empty argument was supplied. If not, it prints usage information and exits with status `2`.

### 6.3 Safe temporary-file handling

The downloaded CSV is stored in a uniquely named temporary file:

```bash
temporary_csv=$(mktemp)
trap 'rm -f "$temporary_csv"' EXIT
```

`mktemp` avoids filename collisions. The `trap` ensures the file is removed when the script exits normally or because of an error. This prevents downloaded data from being left behind unnecessarily.

### 6.4 Download command

The download is performed with:

```bash
curl --fail --location --silent --show-error --max-time 60 \
    --output "$temporary_csv" "$dataset_url"
```

The options mean:

| Option | Purpose |
| --- | --- |
| `--fail` | Returns failure for HTTP errors such as 404 or 500. |
| `--location` | Follows redirects. |
| `--silent` | Suppresses the progress meter. |
| `--show-error` | Still displays useful error messages. |
| `--max-time 60` | Prevents an indefinite wait. |
| `--output` | Writes the CSV to the temporary file. |

The script also checks that the resulting file is not empty.

### 6.5 CSV parsing

A naïve command such as `cut -d','` would fail for valid CSV fields containing commas, for example:

```csv
"New York, NY"
```

Therefore, the script uses Python’s standard-library `csv` module inside the shell script. This is still a Unix shell solution because Bash controls validation, downloading, temporary files, sorting, and output, while Python handles the CSV format correctly.

The embedded parser reads the header and locates columns by normalized names. For example, it can recognize `Security`, `Company`, or `Name` as the company field. It can recognize `Headquarters Location` or `Location` as the location field, and `Founded`, `Founding Year`, or `Year Founded` as the founding field.

Header normalization removes punctuation and converts text to lowercase. This means variations such as `Headquarters Location` and `headquarters_location` can be compared more easily.

Rows that are too short to contain the required fields are skipped. Missing or malformed years are represented as `N/A` rather than causing a crash.

### 6.6 Sorting pipeline

The embedded parser emits four tab-separated fields:

```text
sortable_year    company_name    location    display_year
```

For a normal year, the sortable and display values are the same. For a missing year, the sortable value is `999999999`, which places the record after known years when numerical sorting is applied.

The Unix sorting command is:

```bash
LC_ALL=C sort -t $'\t' -k1,1n -k2,2f
```

The options mean:

| Option | Meaning |
| --- | --- |
| `-t $'\t'` | Uses a tab as the field separator. |
| `-k1,1n` | Sorts the first field numerically. |
| `-k2,2f` | Uses the company name as a case-insensitive tie-breaker. |
| `LC_ALL=C` | Makes sorting behavior predictable across environments. |

Finally, `awk` removes the internal sortable field and formats the remaining values into a readable table with headings for company, location, and founding year.

### 6.7 Example output

```text
Company                                       Location                            Founding year
---------------------------------------------------------------------------------------------------------------
Beta                                          Chicago, IL                         1998
Alpha, Inc.                                   New York, NY                        2001
Gamma                                         Boston, MA                          N/A
```

### 6.8 Shell error cases

The script handles the following basic errors:

| Situation | Behavior |
| --- | --- |
| No URL argument | Prints usage and exits with status `2`. |
| More than one argument | Prints usage and exits with status `2`. |
| Failed download | Prints an error and exits with status `1`. |
| Empty downloaded file | Prints an error and exits with status `1`. |
| Missing CSV header | Prints a processing error and exits with status `1`. |
| Missing required column | Prints which expected column group was not found and exits with status `1`. |
| Missing founding year | Prints `N/A` and sorts the record last. |

## 7. Testing performed

The Python parser was tested using a local HTML fixture containing two distinct product cards and a duplicate card. The test confirmed that product names and prices are extracted and that duplicates are removed. An empty HTML page returned an empty product list. URL construction was also checked for the sample search term.

The Python file was compiled with:

```bash
python3 -m py_compile question1/scraper.py
```

The shell script was syntax-checked with:

```bash
bash -n question3/companies.sh
```

The shell behavior was tested with a local CSV fixture containing a quoted comma in a company name, locations containing commas, founding years in unsorted order, and a missing founding year. The output was confirmed to sort by year and place `N/A` last. The missing-argument case was also checked.

The SQL was reviewed for MySQL-compatible syntax, explicit aliases, join conditions, aggregate handling, `HAVING`, ordering, and page-9 pagination. To generate live result values, run it using the Rfam connection command in Section 5.1. Because Rfam is a live public database, exact result values may change between releases.

## 8. Likely technical-discussion questions and answers

### Why did you use `requests` and BeautifulSoup?

`requests` is a simple HTTP client for retrieving the page, while BeautifulSoup is designed for parsing HTML and selecting elements with CSS selectors. Together they are easier to maintain than regular expressions for HTML extraction.

### Why is the search term passed through `quote_plus()`?

Search terms may contain spaces or special characters. URL encoding converts them into a valid query-string representation and prevents malformed URLs.

### Why did you add selector fallbacks?

Websites can change their HTML classes or use different templates. A few targeted fallback selectors improve resilience without making the scraper unnecessarily complicated.

### What happens if MDComputers returns HTTP 403?

`response.raise_for_status()` raises a request exception. The program catches it, prints a useful error, and exits with status `1`. It does not bypass Cloudflare or pretend that no results were found.

### Why does Query 2C use `HAVING` instead of `WHERE`?

The condition is based on `MAX(r.length)`, which is calculated after rows are grouped by family. Aggregate filters belong in `HAVING`; `WHERE` filters individual rows before aggregation.

### Why is Query 2C grouped by both `rfam_acc` and `rfam_id`?

The output contains both columns, and grouping by both makes the aggregation explicit and compatible with strict SQL modes such as MySQL’s `ONLY_FULL_GROUP_BY`.

### How did you calculate page 9?

With 15 records per page, page 9 begins after eight complete pages: `8 × 15 = 120`. MySQL therefore uses `LIMIT 120, 15`.

### Why not use `cut` to parse the CSV?

CSV fields can contain commas inside double quotes. `cut -d','` does not understand CSV quoting and would split a location such as `"New York, NY"` incorrectly. Python’s `csv` module handles the format correctly.

### Why is Python embedded in a shell script?

Bash is appropriate for argument validation, downloading, temporary-file management, and Unix pipelines. Python’s standard library is appropriate for correctly parsing quoted CSV. This combination remains simple, uses no external package for Question 3, and avoids incorrect field splitting.

### Why are missing years sorted last?

A missing year cannot be sorted chronologically. Assigning it a large internal numeric key places it after known years while still displaying the user-friendly value `N/A`.

### How would you improve the solution in production?

For the scraper, I would add automated tests using saved HTML fixtures, logging, retry/backoff for transient failures, and a configurable base URL. I would also monitor markup changes. For the shell script, I might separate the CSV parsing into a tested helper or use a dedicated CSV utility where available. For SQL, I would inspect execution plans, confirm indexes, and parameterize the taxonomy patterns if the queries became part of an application.

## 9. Submission checklist

| Requirement | Status |
| --- | --- |
| All three questions attempted | Complete |
| Python program accepts non-hard-coded input | Complete |
| SQL queries included in a clearly named file | Complete |
| Shell script accepts URL as command-line argument | Complete |
| README included | Complete |
| Dependencies documented | Complete |
| Basic error handling included | Complete |
| Solutions tested with local fixtures and syntax checks | Complete |
| Meaningful Git history | Complete |
| Repository pushed to GitHub | Complete |
| Google Form submission | Not submitted automatically; paste the repository link manually into the provided form. |

## References

[1]: https://docs.rfam.org/en/latest/database.html "Rfam Public MySQL Database documentation"

[2]: https://mdcomputers.in/ "MDComputers website"
