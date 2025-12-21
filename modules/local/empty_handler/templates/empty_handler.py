#!/usr/bin/env python3
"""
Empty file handler for samples with no mapped reads.

Creates placeholder TSV files with correct headers to ensure
downstream processes have consistent input format.
"""

import csv
import platform

import yaml


def create_virustype_info(sample_id, depth, virus_type):
    """Create empty virus type info file with headers."""
    headers = [
        "sample_id",
        "consensus_sequence_file",
        "depth",
        "serotype_called",
        "reference_sequence_name",
        "reference_sequence_length",
        "number_aligned_bases",
        "coverage_untrimmed",
        "coverage_trimmed",
    ]

    write_dict = {
        "sample_id": sample_id,
        "consensus_sequence_file": "NA",
        "depth": depth,
        "serotype_called": "NA",
        "reference_sequence_name": virus_type,
        "reference_sequence_length": "NA",
        "number_aligned_bases": 0,
        "coverage_untrimmed": 0,
        "coverage_trimmed": 0,
    }

    outfile = f"{sample_id}_all_virustype_info.txt"
    with open(outfile, "w", newline="") as fw:
        writer = csv.DictWriter(fw, delimiter="\\t", fieldnames=headers)
        writer.writeheader()
        writer.writerow(write_dict)


def create_variant_file(sample_id, depth, virus_type):
    """Create empty variants file with headers."""
    headers = [
        "REGION",
        "POS",
        "REF",
        "ALT",
        "REF_DP",
        "REF_RV",
        "REF_QUAL",
        "ALT_DP",
        "ALT_RV",
        "ALT_QUAL",
        "ALT_FREQ",
        "TOTAL_DP",
        "PVAL",
        "PASS",
        "GFF_FEATURE",
        "REF_CODON",
        "REF_AA",
        "ALT_CODON",
        "ALT_AA",
        "POS_AA",
    ]

    outfile = f"{sample_id}.{virus_type}.{depth}.variants.tsv"
    with open(outfile, "w", newline="") as fw:
        writer = csv.DictWriter(fw, delimiter="\\t", fieldnames=headers)
        writer.writeheader()


if __name__ == "__main__":
    # Nextflow variable substitution
    prefix = "$task.ext.prefix" if "$task.ext.prefix" != "null" else "$meta.id"
    depth = "${depth}"
    virus_type = "${virus_type}"

    create_virustype_info(prefix, depth, virus_type)
    create_variant_file(prefix, depth, virus_type)

    # Version reporting
    versions = {
        "${task.process}": {
            "python": platform.python_version(),
        }
    }
    with open("versions.yml", "w") as f:
        f.write(yaml.dump(versions))
