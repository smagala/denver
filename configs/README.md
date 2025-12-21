# Denver Pipeline External Configs

This directory contains configuration overlays for the Denver pipeline that are
separate from the core nf-core pipeline structure. These configs override
container images and docker settings for OAMD infrastructure.

## Files

| File | Purpose |
|------|---------|
| `amd_containers.config` | Container image overrides using OAMD ECR registry |
| `amd_docker.config` | Docker runtime settings for hardened containers |
| `amd_local.config` | Combined config for local development/testing |

## Container Architecture

All OAMD containers are based on `base-ubuntu:24.04` with:

- **Non-root user**: `default` (UID:GID 1001:1001)
- **Read-only rootfs**: Only `/tmp` is writable
- **s5cmd**: Included for AWS Fargate compatibility
- **procps**: Included for Nextflow compatibility

## Usage

### Local Development

```bash
nextflow run main.nf -profile test -c configs/amd_local.config
```

### nf-test

```bash
nf-test test -c configs/amd_local.config
```

### AWS Batch (future)

```bash
nextflow run main.nf -profile aws -c configs/amd_aws.config
```

## Container Versions

Current container versions (as of 2024-12-20):

| Module | Container | Version |
|--------|-----------|---------|
| FASTQC | oamd-bio-fastqc | 0.12.2_07fd4b9_v0 |
| MULTIQC | oamd-bio-multiqc | 1.31_7eb4de1_v0 |
| BWA | oamd-bio-bwa | 0.7.19_28aafd7_v6 |
| SAMTOOLS | oamd-bio-samtools | 1.22.1_f7896d2_v6 |
| IVAR | oamd-bio-ivar | 1.4.4_f85436c_v0 |
| BEDTOOLS | oamd-bio-bedtools | 2.31.1_43a5f7b_v1 |
| NEXTCLADE | oamd-bio-nextclade | 3.18.1-cli_f556ccb_20251220 |
| MAFFT | oamd-bio-mafft | 7.525_a2015e9_20251220 |

## Updating Containers

To check for newer container versions:

```bash
aws --profile amdps ecr list-images \
  --repository-name oamd-bio-<tool> \
  --region us-east-1 \
  --query "imageIds[?imageTag!=null].imageTag" \
  --output table
```
