# smagala/denver

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/smagala/denver)
[![GitHub Actions CI Status](https://github.com/smagala/denver/actions/workflows/nf-test.yml/badge.svg)](https://github.com/smagala/denver/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/smagala/denver/actions/workflows/linting.yml/badge.svg)](https://github.com/smagala/denver/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.5.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.5.1)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/smagala/denver)

## Introduction

**smagala/denver** is a bioinformatics pipeline for analyzing Dengue virus (DENV) Illumina sequencing data. It maps reads against multiple serotype references (DENV1-4 plus sylvatic variants), generates consensus sequences, identifies intra-host variants (iSNVs), and produces quality control visualizations.

This pipeline is a ph-core compliant NextFlow port of the [DENV_pipeline](https://bmcgenomics.biomedcentral.com/articles/10.1186/s12864-024-10350-x) originally developed by Verity Hill & Chrispin Chaguza at the Grubaugh Lab.

### Pipeline Steps

1. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Read mapping to multiple serotype references ([`BWA MEM`](https://github.com/lh3/bwa))
3. Primer trimming ([`iVar trim`](https://andersen-lab.github.io/ivar/html/))
4. Consensus sequence generation ([`iVar consensus`](https://andersen-lab.github.io/ivar/html/))
5. Consensus alignment ([`MAFFT`](https://mafft.cbrc.jp/alignment/software/))
6. Serotype calling based on coverage threshold
7. Variant calling ([`iVar variants`](https://andersen-lab.github.io/ivar/html/))
8. Depth profiling ([`bedtools genomecov`](https://bedtools.readthedocs.io/))
9. QC visualization (variant plots, coverage summaries)
10. Aggregate reporting ([`MultiQC`](http://multiqc.info/))

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
DENV1_sample,DENV1_S1_L001_R1_001.fastq.gz,DENV1_S1_L001_R2_001.fastq.gz
DENV2_sample,DENV2_S2_L001_R1_001.fastq.gz,DENV2_S2_L001_R2_001.fastq.gz
```

Each row represents a paired-end sample for DENV analysis.

Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run smagala/denver \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Credits

smagala/denver was originally written by smagala.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use smagala/denver for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
