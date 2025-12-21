#!/usr/bin/env python3
"""
Filter ivar variants to intrahost SNVs (iSNVs).

Filters variants with allele frequency between 0.2 and 0.8,
indicating true intrahost variation rather than consensus-level mutations.
"""

import csv
import platform

import yaml


# Column name mapping from ivar output to descriptive names
COLUMN_MAPPING = {
    "POS": "position",
    "REF": "reference_base",
    "ALT": "alternative_base",
    "REF_DP": "reference_depth",
    "REF_RV": "reference_depth_reverse",
    "REF_QUAL": "reference_quality",
    "ALT_DP": "alternate_depth",
    "ALT_RV": "alternate_depth_reverse",
    "ALT_QUAL": "alternative_quality",
    "ALT_FREQ": "alternative_frequency",
    "TOTAL_DP": "total_depth",
    "PVAL": "p_value_fisher",
    "PASS": "pass",
    "GFF_FEATURE": "gff_feature",
    "REF_CODON": "reference_codon",
    "REF_AA": "reference_amino_acid",
    "ALT_CODON": "alternative_codon",
    "ALT_AA": "alternative_amino_acid",
}

def filter_variants(variants_file, sample_id, min_freq, max_freq):
    """
    Filter variants to iSNVs (0.2 < freq < 0.8) and rename columns.

    Returns count of filtered variants.
    """
    output_file = f"{sample_id}_variants_frequency.tsv"
    headers = list(COLUMN_MAPPING.values())
    count = 0

    with open(output_file, "w", newline="") as fw:
        writer = csv.DictWriter(fw, fieldnames=headers, delimiter="\\t")
        writer.writeheader()

        with open(variants_file) as f:
            reader = csv.DictReader(f, delimiter="\\t")
            for row in reader:
                # Check filter criteria
                if row.get("PASS") != "TRUE":
                    continue

                try:
                    alt_freq = float(row.get("ALT_FREQ", 0))
                except ValueError:
                    continue

                if not (min_freq < alt_freq < max_freq):
                    continue

                # Map columns to new names
                write_dict = {}
                for old_name, new_name in COLUMN_MAPPING.items():
                    write_dict[new_name] = row.get(old_name, "")

                writer.writerow(write_dict)
                count += 1

    return count


if __name__ == "__main__":
    # Nextflow variable substitution
    prefix = "${task.ext.prefix}" if "${task.ext.prefix}" != "null" else "${meta.id}"
    variants_file = "${variants}"
    min_freq = float("${isnv_min_freq}")
    max_freq = float("${isnv_max_freq}")

    count = filter_variants(variants_file, prefix, min_freq, max_freq)

    # Version reporting
    versions = {
        "${task.process}": {
            "python": platform.python_version(),
        }
    }
    with open("versions.yml", "w") as f:
        f.write(yaml.dump(versions))
