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
