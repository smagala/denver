#!/usr/bin/env python3
"""
QC plots for DENV analysis results.

Creates scatter plots for variant counts and Ct values vs coverage,
colored by serotype.
"""

import csv
import os
import platform

import matplotlib as mpl

mpl.use("Agg")  # Non-interactive backend
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
import yaml
from matplotlib.colors import rgb2hex


def load_serotype_data(serotype_file):
    """Load serotype calls and create color mapping."""
    virus_dict = {}
    all_viruses = set()

    with open(serotype_file) as f:
        reader = csv.DictReader(f, delimiter="\\t")
        for row in reader:
            sample_id = row.get("sample_id", "")
            serotype = row.get("serotype_called", "NA")
            if serotype != "NA":
                virus_dict[sample_id] = serotype
                all_viruses.add(serotype)

    if not all_viruses:
        return None, None, None

    # Create color mapping
    custom_cmap = mpl.colors.LinearSegmentedColormap.from_list(
        "", ["#567CBE", "#D58A80", "#ADB3D9"], len(all_viruses)
    )
    colors = custom_cmap(range(len(all_viruses)))

    colour_dict = {}
    patch_list = []
    for i, serotype in enumerate(sorted(all_viruses)):
        colour_dict[serotype] = rgb2hex(colors[i])
        patch_list.append(mpatches.Patch(color=colour_dict[serotype], label=serotype))

    return virus_dict, colour_dict, patch_list


def create_variant_plot(variants_file, virus_dict, colour_dict, patch_list):
    """Create scatter plot of variant counts per sample."""
    variant_num = {}

    with open(variants_file) as f:
        reader = csv.DictReader(f, delimiter="\\t")
        for row in reader:
            sample_id = row.get("sample_id", "")
            try:
                count = int(row.get("variant_count", 0))
            except ValueError:
                count = 0
            variant_num[sample_id] = count

    # Sort by variant count descending
    variant_num = dict(sorted(variant_num.items(), key=lambda x: x[1], reverse=True))

    fig, ax = plt.subplots(1, 1, figsize=(20, 10))

    x, y, colours = [], [], []
    for sample, count in variant_num.items():
        if sample in virus_dict:
            x.append(sample)
            y.append(count)
            colours.append(colour_dict.get(virus_dict[sample], "#999999"))

    plt.xticks(rotation=90, size=15)
    plt.yticks(size=15)
    plt.scatter(x, y, color=colours, s=70)

    plt.xlabel("Sample ID", size=20)
    plt.ylabel("Variant number", size=20)
    plt.legend(handles=patch_list, fontsize=15, frameon=False)

    plt.savefig("variant_plot.pdf", bbox_inches="tight")
    plt.close()


def create_ct_plot(ct_file, ct_column, id_column, serotype_file, virus_dict, colour_dict, patch_list):
    """Create scatter plot of Ct values vs coverage."""
    if not os.path.exists(ct_file) or ct_file == "NO_FILE":
        return False

    # Load Ct values
    ct_dict = {}
    with open(ct_file) as f:
        reader = csv.DictReader(f)
        for row in reader:
            sample_id = row.get(id_column, "")
            if sample_id not in virus_dict:
                continue
            try:
                value = float(row.get(ct_column, 45))
                if np.isnan(value):
                    value = 45
            except (ValueError, TypeError):
                value = 45
            ct_dict[sample_id] = value

    if not ct_dict:
        return False

    # Load coverage values
    coverage_dict = {}
    with open(serotype_file) as f:
        reader = csv.DictReader(f, delimiter="\\t")
        for row in reader:
            sample_id = row.get("sample_id", "")
            cov_trimmed = row.get("coverage_trimmed", "NA")
            cov_untrimmed = row.get("coverage_untrimmed", "0")

            if cov_trimmed not in ("0", "NA", ""):
                cov = float(cov_trimmed)
            else:
                try:
                    cov = float(cov_untrimmed)
                except ValueError:
                    cov = 0.0
            coverage_dict[sample_id] = cov

    fig, ax = plt.subplots(1, 1, figsize=(20, 10))

    x, y, colours = [], [], []
    for sample, ct in ct_dict.items():
        if sample in coverage_dict and sample in virus_dict:
            x.append(ct)
            y.append(coverage_dict[sample])
            colours.append(colour_dict.get(virus_dict[sample], "#999999"))

    plt.xticks(rotation=90, size=15)
    plt.yticks(size=15)
    plt.scatter(x, y, color=colours, s=70)

    plt.xlabel("Ct value", size=20)
    plt.ylabel("Coverage", size=20)
    plt.legend(handles=patch_list, fontsize=15, frameon=False)

    plt.savefig("ct_plot.pdf", bbox_inches="tight")
    plt.close()

    return True


if __name__ == "__main__":
    # Nextflow variable substitution
    serotype_file = "${serotype_calls}"
    variants_file = "${variants_summary}"
    ct_file = "${ct_file}"
    ct_column = "${ct_column}"
    id_column = "${id_column}"

    # Load serotype data and create color mapping
    virus_dict, colour_dict, patch_list = load_serotype_data(serotype_file)

    if virus_dict:
        # Create variant plot
        create_variant_plot(variants_file, virus_dict, colour_dict, patch_list)

        # Create Ct plot if data available
        create_ct_plot(
            ct_file, ct_column, id_column, serotype_file, virus_dict, colour_dict, patch_list
        )

    # Version reporting
    import matplotlib

    versions = {
        "${task.process}": {
            "python": platform.python_version(),
            "matplotlib": matplotlib.__version__,
            "numpy": np.__version__,
        }
    }
    with open("versions.yml", "w") as f:
        f.write(yaml.dump(versions))
