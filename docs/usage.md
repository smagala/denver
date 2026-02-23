# cdcent/oamd-bio-denver: Usage

## Introduction

The denver pipeline is a Nextflow workflow for analyzing Dengue virus (DENV) sequencing data from amplicon-based protocols. It performs:

- **Read quality control** using Falco (FastQC-compatible)
- **Multi-serotype analysis** against DENV1-4 and sylvatic variants
- **Primer trimming** using iVar with amplicon-specific BED files
- **Consensus sequence generation** with configurable depth and frequency thresholds
- **Variant calling** including intrahost single nucleotide variants (iSNVs)
- **Sequence alignment** using Nextclade (primary) or MAFFT (fallback)
- **Serotype assignment** based on genome coverage metrics
- **QC visualization** with coverage plots and variant summaries

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyze before running the pipeline. Use this parameter to specify its location:

```bash
--input '[path to samplesheet file]'
```

### Samplesheet format

The samplesheet must be a comma-separated file with a header row. The required columns are:

| Column    | Description                                                                                              |
| --------- | -------------------------------------------------------------------------------------------------------- |
| `sample`  | Sample identifier. Spaces are converted to underscores.                                                  |
| `fastq_1` | Full path to FastQ file for read 1. Must be gzipped (`.fastq.gz` or `.fq.gz`).                           |
| `fastq_2` | Full path to FastQ file for read 2 (optional for single-end). Must be gzipped (`.fastq.gz` or `.fq.gz`). |

Optional columns:

| Column | Description                                                       |
| ------ | ----------------------------------------------------------------- |
| `ct`   | Ct value from RT-qPCR. Used for QC correlation plots if provided. |

### Example samplesheet

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2,ct
SAMPLE_001,/path/to/SAMPLE_001_R1.fastq.gz,/path/to/SAMPLE_001_R2.fastq.gz,18.5
SAMPLE_002,/path/to/SAMPLE_002_R1.fastq.gz,/path/to/SAMPLE_002_R2.fastq.gz,22.3
SAMPLE_003,/path/to/SAMPLE_003_R1.fastq.gz,/path/to/SAMPLE_003_R2.fastq.gz,
```

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Reference files

The pipeline requires DENV reference files organized in a specific directory structure:

```
references/
├── refs.txt              # List of serotype names (one per line)
├── DENV1.fasta           # Reference genome for DENV1
├── DENV1.bed             # Primer BED file for DENV1
├── DENV1.trim.bed        # Optional trim regions for DENV1
├── DENV2.fasta
├── DENV2.bed
├── DENV2.trim.bed
├── DENV3.fasta
├── DENV3.bed
├── DENV4.fasta
├── DENV4.bed
├── DENV2_sylvatic.fasta  # Sylvatic variant references
├── DENV2_sylvatic.bed
└── ...
```

The `refs.txt` file should list all serotypes to analyze:

```
DENV1
DENV2
DENV3
DENV4
DENV2_sylvatic
DENV4_sylvatic
```

## Running the pipeline

The typical command for running the pipeline is:

```bash
nextflow run cdcent/oamd-bio-denver \
    --input samplesheet.csv \
    --outdir results \
    --references_base /path/to/references \
    -profile docker
```

This will launch the pipeline with the `docker` configuration profile.

### DENV-specific parameters

| Parameter               | Default | Description                                                  |
| ----------------------- | ------- | ------------------------------------------------------------ |
| `--references_base`     | -       | Path to directory containing DENV reference files            |
| `--serotypes_file`      | -       | Path to refs.txt (defaults to `${references_base}/refs.txt`) |
| `--min_depth`           | 10      | Minimum read depth for consensus base calling                |
| `--consensus_threshold` | 0.75    | Minimum allele frequency for consensus (0-1)                 |
| `--variant_threshold`   | 0.03    | Minimum frequency for variant calling (0-1)                  |
| `--coverage_threshold`  | 0.5     | Minimum genome coverage for serotype assignment (0-1)        |
| `--isnv_min_freq`       | 0.2     | Minimum frequency for iSNV detection (0-1)                   |
| `--isnv_max_freq`       | 0.8     | Maximum frequency for iSNV detection (0-1)                   |
| `--read_cap`            | 10000   | Maximum read depth for mpileup (speeds up high-coverage)     |
| `--skip_qc`             | false   | Skip QC visualization plots                                  |

### Example with parameters

```bash
nextflow run cdcent/oamd-bio-denver \
    --input samplesheet.csv \
    --outdir results \
    --references_base /data/denv_references \
    --min_depth 20 \
    --consensus_threshold 0.8 \
    --coverage_threshold 0.6 \
    -profile docker
```

### Using a params file

For reproducibility, you can specify parameters in a YAML file:

```yaml title="params.yaml"
input: "./samplesheet.csv"
outdir: "./results"
references_base: "/data/denv_references"
min_depth: 20
consensus_threshold: 0.8
coverage_threshold: 0.6
```

Then run with:

```bash
nextflow run cdcent/oamd-bio-denver -profile docker -params-file params.yaml
```

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda):

- `docker` - Use Docker containers
- `singularity` - Use Singularity containers
- `podman` - Use Podman containers
- `apptainer` - Use Apptainer containers
- `conda` - Use Conda environments (not recommended)
- `test` - Run with minimal test data

Multiple profiles can be loaded: `-profile test,docker`

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same:

```bash
nextflow run cdcent/oamd-bio-denver -profile docker -resume
```

### `-c`

Specify the path to a custom config file:

```bash
nextflow run cdcent/oamd-bio-denver -profile docker -c custom.config
```

## Output

See [output documentation](output.md) for a description of all output files.

## Resource requirements

The pipeline has default resource requirements set in `conf/base.config`. You can customize these in a custom config file:

```groovy title="custom.config"
process {
    withName: 'BWA_MEM' {
        cpus = 8
        memory = 16.GB
    }
}
```

## Troubleshooting

### Common issues

1. **No serotype assigned**: Check that genome coverage meets the `--coverage_threshold` parameter. Low Ct samples may have insufficient coverage.

2. **Missing reference files**: Ensure all serotypes listed in `refs.txt` have corresponding `.fasta` and `.bed` files in `references_base`.

3. **Container errors**: Ensure Docker/Singularity is properly configured and images can be pulled.

### Getting help

- Check the [nf-core documentation](https://nf-co.re/docs/usage/introduction)
- Open an issue on the [GitHub repository](https://github.com/cdcent/oamd-bio-denver/issues)
