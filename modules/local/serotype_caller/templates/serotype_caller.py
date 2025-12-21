#!/usr/bin/env python3
"""
Serotype caller for DENV consensus sequences.

Calculates coverage statistics from alignment files and determines
serotype call based on coverage threshold (default >=50%).
"""

import csv
import os
import platform

from Bio import SeqIO
import yaml


# Ambiguous bases to exclude from coverage calculation
AMBIGUOUS_BASES = {"n", "-", "N"}


def calculate_coverage(sequence):
    """Calculate coverage percentage excluding ambiguous bases."""
    seq_len = len(sequence.seq)
    seq_len_no_amb = len([base for base in sequence.seq if base not in AMBIGUOUS_BASES])
    perc_cov = round(seq_len_no_amb / seq_len * 100, 2) if seq_len > 0 else 0.0
    return perc_cov, seq_len, seq_len_no_amb


def parse_alignment_filename(alignment_file):
    """Extract sample ID, serotype, and depth from alignment filename."""
    name_elements = os.path.basename(alignment_file).split(".")
    return {
        "sample_id": name_elements[0],
        "serotype": name_elements[1] if len(name_elements) > 1 else "unknown",
        "depth": name_elements[2] if len(name_elements) > 2 else "NA",
    }


def trim_alignment(sequence, bed_file, output_file):
    """Trim alignment to BED region and write to file."""
    if not os.path.exists(bed_file):
        return None

    with open(bed_file) as f:
        for line in f:
            parts = line.strip().split("\\t")
            if len(parts) >= 2:
                start = int(parts[0]) if parts[0].isdigit() else int(parts[1])
                end = int(parts[1]) if parts[0].isdigit() else int(parts[2])
                break

    trimmed_seq = sequence[start - 1 : end]

    with open(output_file, "w") as fw:
        SeqIO.write(trimmed_seq, fw, "fasta")

    return calculate_coverage(trimmed_seq)[0]


def call_serotype(alignment_file, bed_file, sample_id, min_coverage):
    """
    Process alignment file and determine serotype call.

    Args:
        min_coverage: Minimum coverage percentage for positive call (0-100)

    Returns dict with coverage statistics and serotype call.
    """
    file_info = parse_alignment_filename(alignment_file)

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

    result = {
        "sample_id": sample_id,
        "consensus_sequence_file": f'{sample_id}.{file_info["serotype"]}.{file_info["depth"]}.cons.fa',
        "depth": file_info["depth"],
        "reference_sequence_name": file_info["serotype"],
    }

    # Parse alignment and calculate coverage
    for sequence in SeqIO.parse(alignment_file, "fasta"):
        perc_cov, seq_len, seq_len_no_amb = calculate_coverage(sequence)

        result["reference_sequence_length"] = seq_len
        result["number_aligned_bases"] = seq_len_no_amb
        result["coverage_untrimmed"] = perc_cov

        # Handle trimming if BED file provided
        if bed_file and bed_file != "NO_FILE" and os.path.exists(bed_file):
            trim_output = alignment_file.replace(".out.aln", ".trim.aln")
            if not trim_output.endswith(".trim.aln"):
                trim_output = f"{sample_id}.{file_info['serotype']}.trim.aln"
            perc_cov_trim = trim_alignment(sequence, bed_file, trim_output)
            result["coverage_trimmed"] = perc_cov_trim if perc_cov_trim else "NA"
        else:
            result["coverage_trimmed"] = "NA"

        # Determine serotype call based on coverage threshold
        if perc_cov >= min_coverage:
            result["serotype_called"] = file_info["serotype"]
        else:
            result["serotype_called"] = "NA"

        break  # Only process first sequence

    # Write output TSV
    output_file = f"{sample_id}_serotype_call.tsv"
    with open(output_file, "w", newline="") as fw:
        writer = csv.DictWriter(fw, delimiter="\\t", fieldnames=headers)
        writer.writeheader()
        writer.writerow(result)

    return result


if __name__ == "__main__":
    # Nextflow variable substitution
    prefix = "$task.ext.prefix" if "$task.ext.prefix" != "null" else "$meta.id"
    alignment_file = "${alignment}"
    bed_file = "${bed_file}"
    # Convert from decimal (0.50) to percentage (50)
    min_coverage = float("${coverage_threshold}") * 100

    call_serotype(alignment_file, bed_file, prefix, min_coverage)

    # Version reporting
    import Bio

    versions = {
        "${task.process}": {
            "python": platform.python_version(),
            "biopython": Bio.__version__,
        }
    }
    with open("versions.yml", "w") as f:
        f.write(yaml.dump(versions))
