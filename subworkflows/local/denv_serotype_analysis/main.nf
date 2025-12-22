/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DENV SEROTYPE ANALYSIS SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Per-sample, per-serotype processing: alignment through variant calling.
    This is the core processing chain that runs for each sample×serotype combination.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BWA_MEM                              } from '../../../modules/nf-core/bwa/mem/main'
include { SAMTOOLS_SORT as SAMTOOLS_SORT_ALIGN } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_SORT as SAMTOOLS_SORT_TRIM  } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_FAIDX                       } from '../../../modules/nf-core/samtools/faidx/main'
include { IVAR_TRIM                            } from '../../../modules/nf-core/ivar/trim/main'
include { IVAR_CONSENSUS                       } from '../../../modules/nf-core/ivar/consensus/main'
include { IVAR_VARIANTS                        } from '../../../modules/nf-core/ivar/variants/main'
include { BEDTOOLS_GENOMECOV                   } from '../../../modules/nf-core/bedtools/genomecov/main'
include { MAFFT_ALIGN                          } from '../../../modules/nf-core/mafft/align/main'
include { NEXTCLADE_ALIGN                      } from '../../../modules/local/nextclade/align/main'
include { SEROTYPE_CALLER                      } from '../../../modules/local/serotype_caller/main'
include { FILTER_VARIANTS                      } from '../../../modules/local/filter_variants/main'
include { EMPTY_HANDLER                        } from '../../../modules/local/empty_handler/main'

workflow DENV_SEROTYPE_ANALYSIS {

    take:
    ch_reads           // channel: [ val(meta), [ path(reads) ] ]
    ch_bwa_index       // channel: [ val(meta_ref), path(index) ]
    ch_reference       // channel: [ val(meta_ref), path(fasta) ]
    ch_primer_bed      // channel: path(bed)
    ch_trim_bed        // channel: path(bed) or "NO_FILE"
    min_depth          // val: minimum depth for consensus
    consensus_threshold // val: frequency threshold for consensus
    variant_threshold  // val: frequency threshold for variants
    coverage_threshold // val: coverage threshold for serotype call
    isnv_min_freq      // val: min frequency for iSNV
    isnv_max_freq      // val: max frequency for iSNV
    read_cap           // val: max depth for mpileup

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Index reference FASTA (needed for IVAR_VARIANTS)
    //
    SAMTOOLS_FAIDX (
        ch_reference,
        [[:], []],  // existing fai (none)
        false       // don't create sizes file
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions.first())

    //
    // MODULE: Align reads with BWA MEM
    // sort_bam=false allows filtering via args2, then sort separately
    //
    BWA_MEM (
        ch_reads,
        ch_bwa_index,
        ch_reference,
        false  // sort_bam = false
    )
    ch_versions = ch_versions.mix(BWA_MEM.out.versions.first())

    //
    // MODULE: Sort aligned BAM and create index
    //
    SAMTOOLS_SORT_ALIGN (
        BWA_MEM.out.bam,
        ch_reference,
        "bai"  // create BAI index
    )

    //
    // Combine BAM with BAI for IVAR_TRIM
    //
    SAMTOOLS_SORT_ALIGN.out.bam
        .join(SAMTOOLS_SORT_ALIGN.out.bai)
        .set { ch_sorted_bam_bai }

    //
    // MODULE: Trim primers with ivar
    //
    IVAR_TRIM (
        ch_sorted_bam_bai,
        ch_primer_bed
    )
    ch_versions = ch_versions.mix(IVAR_TRIM.out.versions.first())

    //
    // Branch: Check if trimmed BAM has reads
    // BAM header is ~few hundred bytes, empty BAM is small
    //
    IVAR_TRIM.out.bam
        .branch { meta, bam ->
            has_reads: bam.size() > 1000
            empty: true
        }
        .set { ch_trimmed_branch }

    //
    // MODULE: Handle empty samples (no reads after trimming)
    //
    ch_trimmed_branch.empty
        .map { meta, bam ->
            def serotype = meta.serotype ?: "UNKNOWN"
            [ meta, serotype ]
        }
        .set { ch_empty_samples }

    EMPTY_HANDLER (
        ch_empty_samples,  // tuple of [meta, serotype]
        min_depth
    )
    ch_versions = ch_versions.mix(EMPTY_HANDLER.out.versions.first().ifEmpty([]))

    //
    // Continue processing for samples with reads
    //

    //
    // MODULE: Sort trimmed BAM
    //
    SAMTOOLS_SORT_TRIM (
        ch_trimmed_branch.has_reads,
        ch_reference,
        "bai"
    )

    //
    // Prepare indexed BAM for downstream processes
    //
    SAMTOOLS_SORT_TRIM.out.bam
        .join(SAMTOOLS_SORT_TRIM.out.bai)
        .map { meta, bam, bai -> [ meta, bam ] }
        .set { ch_indexed_bam }

    //
    // MODULE: Generate consensus sequence
    // IVAR_CONSENSUS runs mpileup internally
    //
    IVAR_CONSENSUS (
        ch_indexed_bam,
        ch_reference.map { meta, fasta -> fasta },
        false  // save_mpileup
    )
    ch_versions = ch_versions.mix(IVAR_CONSENSUS.out.versions.first())

    //
    // MODULE: Align consensus to reference
    //
    NEXTCLADE_ALIGN (
        IVAR_CONSENSUS.out.fasta,
        ch_reference.map { meta, fasta -> fasta }
    )
    ch_versions = ch_versions.mix(NEXTCLADE_ALIGN.out.versions.first())

    //
    // Check for empty alignment (nextalign failure)
    // If empty, fall back to MAFFT
    //
    NEXTCLADE_ALIGN.out.alignment
        .branch { meta, aln ->
            has_alignment: aln.size() > 0
            empty: true
        }
        .set { ch_alignment_branch }

    //
    // MODULE: MAFFT fallback for failed nextalign
    // Original uses: mafft --quiet --6merpair --keeplength --addfragments consensus reference
    //
    ch_alignment_branch.empty
        .join(IVAR_CONSENSUS.out.fasta)
        .map { meta, empty_aln, consensus -> [ meta, consensus ] }
        .set { ch_for_mafft }

    // Prepare inputs for MAFFT: reference as main fasta, consensus as addfragments
    MAFFT_ALIGN (
        ch_reference,              // fasta (reference)
        [[:], []],                 // add
        ch_for_mafft,              // addfragments (consensus)
        [[:], []],                 // addfull
        [[:], []],                 // addprofile
        [[:], []],                 // addlong
        false                      // compress
    )
    ch_versions = ch_versions.mix(MAFFT_ALIGN.out.versions.first().ifEmpty([]))

    //
    // Combine alignment outputs
    //
    ch_alignment_branch.has_alignment
        .mix(MAFFT_ALIGN.out.fas)
        .set { ch_alignments }

    //
    // MODULE: Calculate coverage and call serotype
    //
    SEROTYPE_CALLER (
        ch_alignments,
        ch_trim_bed,
        coverage_threshold
    )
    ch_versions = ch_versions.mix(SEROTYPE_CALLER.out.versions.first())

    //
    // MODULE: Call variants
    // IVAR_VARIANTS runs mpileup internally with different params
    //
    IVAR_VARIANTS (
        ch_indexed_bam,
        ch_reference.map { meta, fasta -> fasta },
        SAMTOOLS_FAIDX.out.fai.map { meta, fai -> fai },
        [],    // No GFF
        false  // save_mpileup
    )
    ch_versions = ch_versions.mix(IVAR_VARIANTS.out.versions.first())

    //
    // MODULE: Filter variants for iSNV
    //
    FILTER_VARIANTS (
        IVAR_VARIANTS.out.tsv,
        isnv_min_freq,
        isnv_max_freq
    )
    ch_versions = ch_versions.mix(FILTER_VARIANTS.out.versions.first())

    //
    // MODULE: Calculate depth coverage
    //
    ch_indexed_bam
        .map { meta, bam -> [ meta, bam, 1 ] }  // scale = 1
        .set { ch_for_genomecov }

    BEDTOOLS_GENOMECOV (
        ch_for_genomecov,
        [],    // no sizes file (using BAM)
        "txt", // output extension
        false  // don't sort
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GENOMECOV.out.versions.first())

    //
    // Combine outputs from both branches (has_reads + empty)
    //
    ch_serotype_call = SEROTYPE_CALLER.out.serotype_call
        .mix(EMPTY_HANDLER.out.virustype_info)

    ch_variants = FILTER_VARIANTS.out.filtered_variants
        .mix(EMPTY_HANDLER.out.variants)

    emit:
    consensus      = IVAR_CONSENSUS.out.fasta       // channel: [ val(meta), path(fasta) ]
    alignment      = ch_alignments                   // channel: [ val(meta), path(aln) ]
    serotype_call  = ch_serotype_call               // channel: [ val(meta), path(tsv) ]
    variants       = ch_variants                    // channel: [ val(meta), path(tsv) ]
    depth          = BEDTOOLS_GENOMECOV.out.genomecov // channel: [ val(meta), path(txt) ]
    bam            = ch_indexed_bam                 // channel: [ val(meta), path(bam) ]
    versions       = ch_versions                    // channel: [ path(versions.yml) ]
}
