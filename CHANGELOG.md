# ph-core/denver: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - 2025-12-21

Initial release of ph-core/denver, a Dengue virus (DENV) analysis pipeline built with the [nf-core](https://nf-co.re/) template.

### `Added`

- Multi-serotype analysis against DENV1-4 and sylvatic variants (DENV2_sylvatic, DENV4_sylvatic)
- Read quality control using Falco (FastQC-compatible, 3x faster)
- BWA-MEM alignment to serotype-specific reference genomes
- iVar primer trimming with amplicon-specific BED files
- iVar consensus sequence generation with configurable depth and frequency thresholds
- iVar variant calling with intrahost SNV (iSNV) detection
- Nextclade sequence alignment (primary) with MAFFT fallback
- Serotype assignment based on genome coverage metrics
- Coverage profiling using bedtools genomecov
- Results summarization across all samples
- QC visualization plots (coverage vs Ct correlation, variant summaries)
- MultiQC report aggregating all QC metrics
- Configurable analysis parameters (min_depth, consensus_threshold, coverage_threshold, etc.)
- External asset management for reference files
- CI/CD workflows with nf-test integration

### `Dependencies`

| Tool      | Version |
| --------- | ------- |
| BWA       | 0.7.18  |
| bedtools  | 2.31.1  |
| Falco     | 1.2.3   |
| iVar      | 1.4.3   |
| MAFFT     | 7.526   |
| MultiQC   | 1.25.2  |
| Nextclade | 3.10.2  |
| SAMtools  | 1.21    |

### `Fixed`

- Falco module: Fixed paired-end read handling where outputs were overwriting each other (upstream nf-core bug)
- SnakeYAML compatibility: Fixed yaml.load() to accept Nextflow Path objects on NF 25.x

### `Deprecated`

- N/A
