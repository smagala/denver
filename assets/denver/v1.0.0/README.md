# Denver Pipeline Assets v1.0.0

## Overview

Reference files for Dengue virus (DENV) analysis including reference genomes and primer coordinates.

## Contents

### Reference Genomes (`references/`)

| File | Description | Size |
|------|-------------|------|
| DENV1.fasta | Dengue virus serotype 1 reference | ~10.7 KB |
| DENV2.fasta | Dengue virus serotype 2 reference | ~10.9 KB |
| DENV3.fasta | Dengue virus serotype 3 reference | ~10.9 KB |
| DENV4.fasta | Dengue virus serotype 4 reference | ~10.8 KB |
| DENV2_sylvatic.fasta | Dengue virus serotype 2 sylvatic variant | ~10.9 KB |
| DENV4_sylvatic.fasta | Dengue virus serotype 4 sylvatic variant | ~10.7 KB |

### Primer BED Files (`references/`)

| File | Description |
|------|-------------|
| DENV1.bed | Primer coordinates for DENV1 amplicon trimming |
| DENV2.bed | Primer coordinates for DENV2 amplicon trimming |
| DENV3.bed | Primer coordinates for DENV3 amplicon trimming |
| DENV4.bed | Primer coordinates for DENV4 amplicon trimming |
| DENV2_sylvatic.bed | Primer coordinates for DENV2 sylvatic |
| DENV4_sylvatic.bed | Primer coordinates for DENV4 sylvatic |

### Trim Region BED Files (`references/`)

| File | Description |
|------|-------------|
| *.trim.bed | Region coordinates for coverage calculation |

### Serotype List

| File | Description |
|------|-------------|
| refs.txt | List of all serotype names (one per line) |

## Usage

These assets are automatically used by the denver pipeline when no custom references are provided.

To use custom references:
```bash
nextflow run smagala/denver --references /path/to/custom/refs
```

## Source

Original reference files from the DENV_pipeline project:
- Citation: https://bmcgenomics.biomedcentral.com/articles/10.1186/s12864-024-10350-x
- Authors: Verity Hill & Chrispin Chaguza, Grubaugh Lab

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-20 | Initial release with DENV1-4 and sylvatic variants |
