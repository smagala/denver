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
include { SAMTOOLS_STATS                       } from '../../../modules/nf-core/samtools/stats/main'
include { SAMTOOLS_FLAGSTAT                    } from '../../../modules/nf-core/samtools/flagstat/main'
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
    ch_reads           // channel: [ val(meta), [ path(reads) ] ] - meta includes serotype
    ch_bwa_index       // channel: [ val(serotype_id), path(index) ]
    ch_reference       // channel: [ val(serotype_id), path(fasta) ]
    ch_primer_bed      // channel: [ val(serotype_id), path(bed) ]
    ch_trim_bed        // channel: [ val(serotype_id), path(bed) ] or "NO_FILE"
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
    // Join reads with their corresponding reference data by serotype
    // This ensures each sample×serotype combination gets correct references
    //
    ch_reads
        .map { meta, reads -> [ meta.serotype, meta, reads ] }
        .combine(ch_bwa_index, by: 0)
        .combine(ch_reference, by: 0)
        .combine(ch_primer_bed, by: 0)
        .combine(ch_trim_bed, by: 0)
        .map { serotype, meta, reads, index, fasta, bed, trim_bed ->
            [ meta, reads, index, fasta, bed, trim_bed ]
        }
        .set { ch_joined }

    // Extract individual channels for module inputs - maintain 1:1 correspondence
    // Each sample×serotype gets its own matched reference files
    ch_joined.map { meta, reads, index, fasta, bed, trim_bed -> [ meta, reads ] }
        .set { ch_reads_joined }

    ch_joined.map { meta, reads, index, fasta, bed, trim_bed -> [ meta, index ] }
        .set { ch_index_joined }

    ch_joined.map { meta, reads, index, fasta, bed, trim_bed -> [ meta, fasta ] }
        .set { ch_fasta_joined }

    // Unique fasta channel for SAMTOOLS_FAIDX (only need one per serotype)
    ch_reference
        .map { serotype, fasta -> [ [id: serotype], fasta ] }
        .set { ch_fasta_for_faidx }

    //
    // MODULE: Index reference FASTA (needed for IVAR_VARIANTS)
    //
    SAMTOOLS_FAIDX (
        ch_fasta_for_faidx,
        [[:], []],  // existing fai (none)
        false       // don't create sizes file
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions.first())

    //
    // MODULE: Align reads with BWA MEM
    // sort_bam=false allows filtering via args2, then sort separately
    //
    BWA_MEM (
        ch_reads_joined,
        ch_index_joined,
        ch_fasta_joined,
        false  // sort_bam = false
    )
    ch_versions = ch_versions.mix(BWA_MEM.out.versions.first())

    //
    // MODULE: Sort aligned BAM and create index
    // Join BAM with its corresponding fasta for sorting
    //
    BWA_MEM.out.bam
        .join(ch_fasta_joined)
        .multiMap { meta, bam, fasta ->
            bam: [ meta, bam ]
            fasta: [ meta, fasta ]
        }
        .set { ch_for_sort_align }

    SAMTOOLS_SORT_ALIGN (
        ch_for_sort_align.bam,
        ch_for_sort_align.fasta,
        "bai"  // create BAI index
    )

    //
    // Combine BAM with BAI for IVAR_TRIM
    //
    SAMTOOLS_SORT_ALIGN.out.bam
        .join(SAMTOOLS_SORT_ALIGN.out.bai)
        .set { ch_sorted_bam_bai }

    //
    // Join BAM with correct primer BED by serotype
    //
    ch_sorted_bam_bai
        .map { meta, bam, bai -> [ meta.serotype, meta, bam, bai ] }
        .combine(ch_primer_bed, by: 0)
        .map { serotype, meta, bam, bai, bed -> [ [meta, bam, bai], bed ] }
        .set { ch_bam_with_bed }

    //
    // MODULE: Trim primers with ivar
    //
    IVAR_TRIM (
        ch_bam_with_bed.map { it[0] },  // [meta, bam, bai]
        ch_bam_with_bed.map { it[1] }   // bed (per-serotype)
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
    // Join trimmed BAM with corresponding fasta
    //
    ch_trimmed_branch.has_reads
        .join(ch_fasta_joined)
        .multiMap { meta, bam, fasta ->
            bam: [ meta, bam ]
            fasta: [ meta, fasta ]
        }
        .set { ch_for_sort_trim }

    SAMTOOLS_SORT_TRIM (
        ch_for_sort_trim.bam,
        ch_for_sort_trim.fasta,
        "bai"
    )

    //
    // Prepare indexed BAM for downstream processes
    //
    SAMTOOLS_SORT_TRIM.out.bam
        .join(SAMTOOLS_SORT_TRIM.out.bai)
        .set { ch_bam_bai }

    ch_bam_bai
        .map { meta, bam, bai -> [ meta, bam ] }
        .set { ch_indexed_bam }

    //
    // Join indexed BAM with reference FASTA by serotype for downstream modules
    //
    ch_indexed_bam
        .map { meta, bam -> [ meta.serotype, meta, bam ] }
        .combine(ch_reference, by: 0)
        .map { serotype, meta, bam, fasta -> [ meta, bam, fasta ] }
        .set { ch_bam_with_ref }

    //
    // MODULE: Generate consensus sequence
    // IVAR_CONSENSUS runs mpileup internally
    //
    IVAR_CONSENSUS (
        ch_bam_with_ref.map { meta, bam, fasta -> [ meta, bam ] },
        ch_bam_with_ref.map { meta, bam, fasta -> fasta },
        false  // save_mpileup
    )
    ch_versions = ch_versions.mix(IVAR_CONSENSUS.out.versions.first())

    //
    // Join consensus with reference for alignment
    //
    IVAR_CONSENSUS.out.fasta
        .map { meta, fasta -> [ meta.serotype, meta, fasta ] }
        .combine(ch_reference, by: 0)
        .map { serotype, meta, consensus, ref_fasta -> [ meta, consensus, ref_fasta ] }
        .set { ch_consensus_with_ref }

    //
    // MODULE: Align consensus to reference
    //
    NEXTCLADE_ALIGN (
        ch_consensus_with_ref.map { meta, consensus, ref -> [ meta, consensus ] },
        ch_consensus_with_ref.map { meta, consensus, ref -> ref }
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
        .map { meta, empty_aln, consensus -> [ meta.serotype, meta, consensus ] }
        .combine(ch_reference, by: 0)
        .map { serotype, meta, consensus, ref_fasta -> [ meta, consensus, ref_fasta ] }
        .set { ch_for_mafft }

    // Prepare inputs for MAFFT: reference as main fasta, consensus as addfragments
    MAFFT_ALIGN (
        ch_for_mafft.map { meta, consensus, ref -> [ [id: meta.serotype], ref ] },  // fasta (reference)
        [[:], []],                 // add
        ch_for_mafft.map { meta, consensus, ref -> [ meta, consensus ] },  // addfragments (consensus)
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
    // Join alignments with trim BED by serotype for SEROTYPE_CALLER
    //
    ch_alignments
        .map { meta, aln -> [ meta.serotype, meta, aln ] }
        .combine(ch_trim_bed, by: 0)
        .map { serotype, meta, aln, bed -> [ meta, aln, bed ] }
        .set { ch_aln_with_trim_bed }

    //
    // MODULE: Calculate coverage and call serotype
    //
    SEROTYPE_CALLER (
        ch_aln_with_trim_bed.map { meta, aln, bed -> [ meta, aln ] },
        ch_aln_with_trim_bed.map { meta, aln, bed -> bed },
        coverage_threshold
    )
    ch_versions = ch_versions.mix(SEROTYPE_CALLER.out.versions.first())

    //
    // Join BAM with reference and FAI for variant calling
    //
    ch_bam_with_ref
        .map { meta, bam, fasta -> [ meta.serotype, meta, bam, fasta ] }
        .combine(SAMTOOLS_FAIDX.out.fai.map { ref_meta, fai -> [ ref_meta.id, fai ] }, by: 0)
        .map { serotype, meta, bam, fasta, fai -> [ meta, bam, fasta, fai ] }
        .set { ch_bam_ref_fai }

    //
    // MODULE: Call variants
    // IVAR_VARIANTS runs mpileup internally with different params
    //
    IVAR_VARIANTS (
        ch_bam_ref_fai.map { meta, bam, fasta, fai -> [ meta, bam ] },
        ch_bam_ref_fai.map { meta, bam, fasta, fai -> fasta },
        ch_bam_ref_fai.map { meta, bam, fasta, fai -> fai },
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
    // MODULE: Generate BAM statistics for MultiQC
    //
    ch_bam_bai
        .map { meta, bam, bai -> [ meta.serotype, meta, bam, bai ] }
        .combine(ch_reference, by: 0)
        .map { serotype, meta, bam, bai, fasta -> [ [ meta, bam, bai ], [ [id: serotype], fasta ] ] }
        .multiMap { bam_tuple, ref_tuple ->
            bam: bam_tuple
            ref: ref_tuple
        }
        .set { ch_for_stats }

    SAMTOOLS_STATS (
        ch_for_stats.bam,
        ch_for_stats.ref
    )

    //
    // MODULE: Generate BAM flagstat for MultiQC
    //
    SAMTOOLS_FLAGSTAT (
        ch_bam_bai
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT.out.versions.first())

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
    consensus      = IVAR_CONSENSUS.out.fasta         // channel: [ val(meta), path(fasta) ]
    alignment      = ch_alignments                     // channel: [ val(meta), path(aln) ]
    serotype_call  = ch_serotype_call                 // channel: [ val(meta), path(tsv) ]
    variants       = ch_variants                      // channel: [ val(meta), path(tsv) ]
    depth          = BEDTOOLS_GENOMECOV.out.genomecov // channel: [ val(meta), path(txt) ]
    bam            = ch_indexed_bam                   // channel: [ val(meta), path(bam) ]
    // MultiQC-compatible outputs
    ivar_trim_log  = IVAR_TRIM.out.log                // channel: [ val(meta), path(log) ]
    samtools_stats = SAMTOOLS_STATS.out.stats         // channel: [ val(meta), path(stats) ]
    flagstat       = SAMTOOLS_FLAGSTAT.out.flagstat   // channel: [ val(meta), path(flagstat) ]
    nextclade_csv  = NEXTCLADE_ALIGN.out.csv          // channel: [ val(meta), path(csv) ]
    versions       = ch_versions                      // channel: [ path(versions.yml) ]
}
