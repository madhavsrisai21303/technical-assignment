-- Rfam public MySQL database
-- Connection details: https://docs.rfam.org/en/latest/database.html
--
-- The taxonomy table stores the NCBI taxonomic string in tax_string and links
-- to rfamseq through ncbi_id. Sequence lengths are stored in rfamseq.length.

/*
  A. Count taxonomy entries whose lineage contains Acacia.

  COUNT(*) counts matching taxonomy records (taxonomic entries), rather than
  counting sequence rows, so the result is not inflated by Rfam annotations.
*/
SELECT COUNT(*) AS acacia_taxonomy_types
FROM taxonomy AS t
WHERE t.tax_string LIKE '%Acacia%';

/*
  B. Find the wheat taxonomic entry with the longest associated DNA sequence.

  The case-insensitive collation used by the public database normally makes
  LIKE case-insensitive. LOWER() keeps the intent explicit and portable.
  The second predicate includes the common scientific genus for wheat.
*/
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
/*
  C. Return page 9 (rows 121--135) of families whose maximum associated
  sequence length is greater than 1,000,000 nucleotides.

  full_region connects an Rfam family to an rfamseq sequence. Grouping by
  family ensures that MAX() is calculated once per family before pagination.
  MySQL uses a zero-based offset: (page - 1) * page_size = 8 * 15 = 120.
*/
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
