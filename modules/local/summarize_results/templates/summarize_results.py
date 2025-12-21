#!/usr/bin/env python3
"""
Summarize results across all samples.

Aggregates per-sample serotype calls and variant counts into
summary files for reporting.
"""

import csv
import glob
import platform
from collections import defaultdict

import yaml


def summarize_serotype_calls(serotype_files, min_coverage):
    """
    Aggregate serotype calls from all samples.

    Returns:
        - all_lines: All sample/serotype combinations
        - serotype_calls: Samples meeting coverage threshold
        - top_calls: Highest coverage call per sample
        - low_coverage: Samples below threshold with best guess
    """
    all_coverage = defaultdict(dict)
    all_lines = []
    top_calls = []
    serotype_calls = []
    serotypes = defaultdict(list)

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

    for filepath in serotype_files:
        possible_tops = []
        with open(filepath) as f:
            reader = csv.DictReader(f, delimiter="\\t")
            for row in reader:
                sample_id = row.get("sample_id", "")
                ref_name = row.get("reference_sequence_name", "")

                try:
                    coverage = float(row.get("coverage_untrimmed", 0))
                except ValueError:
                    coverage = 0.0

                all_coverage[sample_id][ref_name] = coverage
                possible_tops.append(row)
                all_lines.append(row)

                if coverage >= min_coverage:
                    serotype_calls.append(row)
                    serotypes[sample_id].append(row.get("serotype_called", "NA"))

        # Find top call for this sample (highest coverage)
        if possible_tops:
            top = max(possible_tops, key=lambda x: float(x.get("coverage_untrimmed", 0)))
            top_calls.append(top)

    # Identify low coverage samples
    low_coverage = identify_low_coverage(all_coverage, serotypes)

    return headers, all_lines, serotype_calls, top_calls, low_coverage


def identify_low_coverage(all_coverage, high_coverage_samples):
    """
    Identify best serotype guess for samples below coverage threshold.

    Uses coverage difference logic to determine if a clear winner exists.
    """
    low_coverage = []

    for sample_id, cov_dict in all_coverage.items():
        if sample_id in high_coverage_samples:
            continue

        coverages = sorted(cov_dict.values(), reverse=True)
        if not coverages:
            continue

        if len(coverages) == 1:
            top = [k for k, v in cov_dict.items() if v == coverages[0]][0]
        elif coverages[0] > (coverages[1] + 5):
            # Clear winner (>5% difference)
            top = [k for k, v in cov_dict.items() if v == coverages[0]][0]
        else:
            # Check for sylvatic variant confusion
            first = [k for k, v in cov_dict.items() if v == coverages[0]][0]
            second = [k for k, v in cov_dict.items() if v == coverages[1]][0]

            if f"{second}_sylvatic" == first or f"{first}_sylvatic" == second:
                if len(coverages) > 2 and coverages[0] > (coverages[2] + 5):
                    top = first
                else:
                    top = "NA"
            else:
                top = "NA"

        if top != "NA":
            low_coverage.append({"sample_id": sample_id, "serotype": top})

    return low_coverage


def summarize_variant_counts(variant_files, serotype_calls):
    """Aggregate variant counts per sample."""
    # Build sample->serotype mapping from serotype calls
    sample_serotypes = {}
    for call in serotype_calls:
        sample_id = call.get("sample_id", "")
        serotype = call.get("serotype_called", "NA")
        if serotype != "NA":
            sample_serotypes[sample_id] = serotype

    # Count variants per sample
    variant_counts = []
    for filepath in variant_files:
        with open(filepath) as f:
            reader = csv.DictReader(f, delimiter="\\t")
            count = sum(1 for _ in reader)

        # Extract sample ID from filename
        filename = filepath.split("/")[-1] if "/" in filepath else filepath
        parts = filename.replace("_variants_frequency.tsv", "").split(".")
        sample_id = parts[0]

        if sample_id in sample_serotypes:
            variant_counts.append(
                {
                    "sample_id": sample_id,
                    "serotype": sample_serotypes[sample_id],
                    "variant_count": count,
                }
            )

    return variant_counts


def write_outputs(headers, all_lines, serotype_calls, top_calls, low_coverage, variant_counts):
    """Write all output files."""
    # Serotype calls (samples meeting threshold)
    with open("serotype_calls.tsv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=headers, delimiter="\\t")
        writer.writeheader()
        writer.writerows(serotype_calls)

    # Top calls (highest coverage per sample)
    with open("top_calls.tsv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=headers, delimiter="\\t")
        writer.writeheader()
        writer.writerows(top_calls)

    # All info (complete matrix)
    with open("all_info.tsv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=headers, delimiter="\\t")
        writer.writeheader()
        writer.writerows(all_lines)

    # Low coverage calls
    with open("low_coverage_calls.csv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["sample_id", "serotype"])
        writer.writeheader()
        writer.writerows(low_coverage)

    # Variants summary
    with open("variants_summary.tsv", "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["sample_id", "serotype", "variant_count"], delimiter="\\t"
        )
        writer.writeheader()
        writer.writerows(variant_counts)


if __name__ == "__main__":
    # Nextflow variable substitution
    # Convert from decimal (0.50) to percentage (50)
    min_coverage = float("${coverage_threshold}") * 100

    # Find input files (Nextflow stages them in work directory)
    serotype_files = glob.glob("*_serotype_call.tsv") + glob.glob("*_all_virustype_info.txt")
    variant_files = glob.glob("*_variants_frequency.tsv")

    # Process serotype calls
    headers, all_lines, serotype_calls, top_calls, low_coverage = summarize_serotype_calls(
        serotype_files, min_coverage
    )

    # Process variant counts
    variant_counts = summarize_variant_counts(variant_files, serotype_calls)

    # Write outputs
    write_outputs(headers, all_lines, serotype_calls, top_calls, low_coverage, variant_counts)

    # Version reporting
    versions = {
        "${task.process}": {
            "python": platform.python_version(),
        }
    }
    with open("versions.yml", "w") as f:
        f.write(yaml.dump(versions))
