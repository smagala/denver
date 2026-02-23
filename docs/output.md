# cdcent/oamd-bio-denver: Output

## Introduction

This document describes the output produced by the pipeline. The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [Falco](#falco) - Raw read QC
- [Alignment](#alignment) - Read alignment to reference
- [Trimmed](#trimmed) - Primer-trimmed BAM files
- [Consensus](#consensus) - Consensus sequences
- [Variants](#variants) - Variant calls
- [Coverage](#coverage) - Depth profiles
- [Serotype calls](#serotype-calls) - Serotype assignments
- [Results](#results) - Summary tables and QC plots
- [MultiQC](#multiqc) - Aggregate report
- [Pipeline information](#pipeline-information) - Execution metrics

### Falco

<details markdown="1">
<summary>Output files</summary>

- `falco/`
  - `*_fastqc_report.html`: Falco HTML report containing quality metrics (FastQC-compatible format).
  - `*_fastqc_data.txt`: Tab-delimited data file with QC metrics.
  - `*_summary.txt`: Summary of pass/warn/fail status for each QC metric.

</details>

[Falco](https://github.com/smithlabcode/falco) is a high-speed FastQC emulation tool that provides general quality metrics about your sequenced reads. It is 3x faster than FastQC while producing equivalent results. Falco provides information about the quality score distribution across your reads, per base sequence content (%A/T/G/C), adapter contamination and overrepresented sequences. The output is fully compatible with MultiQC's FastQC module.

### Alignment

<details markdown="1">
<summary>Output files</summary>

- `alignment/`
  - `*.sorted.bam`: Sorted BAM file after primer trimming.
  - `*.aln.fasta`: Aligned consensus sequence (from Nextclade or MAFFT).

</details>

Reads are aligned to each serotype reference using BWA-MEM. After primer trimming with iVar, the sorted BAM files are published for downstream analysis.

### Trimmed

<details markdown="1">
<summary>Output files</summary>

- `trimmed/`
  - `*.trimmed.bam`: BAM files after iVar primer trimming.

</details>

[iVar](https://github.com/andersen-lab/ivar) trims primer sequences from aligned reads using amplicon-specific BED files. This step also performs Q20 sliding window quality trimming.

### Consensus

<details markdown="1">
<summary>Output files</summary>

- `consensus/`
  - `*.cons.fa`: Consensus FASTA sequence for each sample-serotype combination.

</details>

Consensus sequences are generated using iVar consensus with configurable parameters:

- `--min_depth`: Minimum read depth for base calling (default: 10)
- `--consensus_threshold`: Minimum allele frequency (default: 0.75)

Positions below the depth threshold are called as N.

### Variants

<details markdown="1">
<summary>Output files</summary>

- `variants/`
  - `*.variants.tsv`: Raw variant calls from iVar variants.
  - `*_variants_frequency.tsv`: Filtered variants with frequency annotations.

</details>

Variants are called using iVar variants and filtered based on the `--variant_threshold` parameter. The filtered output includes annotations for intrahost single nucleotide variants (iSNVs) based on the `--isnv_min_freq` and `--isnv_max_freq` thresholds.

### Coverage

<details markdown="1">
<summary>Output files</summary>

- `coverage/`
  - `*.depth.txt`: Per-position depth profile from bedtools genomecov.

</details>

Depth profiles are generated using bedtools genomecov with the `-d` flag to report depth at each genomic position.

### Serotype calls

<details markdown="1">
<summary>Output files</summary>

- `serotype_calls/`
  - `*.serotype_call.tsv`: Serotype assignment for each sample-serotype combination.

</details>

Each sample is analyzed against all configured serotypes. The serotype caller computes genome coverage and assigns serotypes based on the `--coverage_threshold` parameter.

### Results

<details markdown="1">
<summary>Output files</summary>

- `results/`
  - `serotype_calls_summary.tsv`: Aggregated serotype assignments across all samples.
  - `variants_summary.tsv`: Aggregated variant calls across all samples.
  - `coverage_vs_ct.pdf`: Scatter plot of genome coverage vs Ct values (if Ct provided).
  - `variants_by_sample.pdf`: Variant frequency plots by sample.

</details>

The results directory contains summary tables aggregating data across all samples, plus QC visualization plots when `--skip_qc` is false.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: A standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: Directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: Directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarizing all samples in your project. Most of the pipeline QC results are visualized in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. Falco (via FastQC module). The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.
  - `denver_software_mqc_versions.yml`: Software versions used in the pipeline run.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
