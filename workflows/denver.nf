/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FALCO                       } from '../modules/ph-core/falco/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { BWA_INDEX                   } from '../modules/nf-core/bwa/index/main'
include { SUMMARIZE_RESULTS           } from '../modules/local/summarize_results/main'
include { QC_PLOTS                    } from '../modules/local/qc_plots/main'
include { DENV_SEROTYPE_ANALYSIS      } from '../subworkflows/local/denv_serotype_analysis/main'
include { paramsSummaryMap            } from 'plugin/nf-schema'
include { paramsSummaryMultiqc        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText      } from '../subworkflows/local/utils_nfcore_denver_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DENVER {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run Falco (FastQC-compatible read QC)
    //
    FALCO (
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(FALCO.out.txt.collect{it[1]})

    //
    // Load serotype references from refs.txt
    //
    Channel
        .fromPath(params.serotypes_file)
        .splitText()
        .map { it.trim() }
        .filter { it }  // Remove empty lines
        .set { ch_serotypes }

    //
    // Create channels for each serotype's reference files
    //
    ch_serotypes
        .map { serotype ->
            def fasta = file("${params.references_base}/${serotype}.fasta", checkIfExists: true)
            def bed = file("${params.references_base}/${serotype}.bed", checkIfExists: true)
            def trim_bed = file("${params.references_base}/${serotype}.trim.bed")
            def trim_bed_path = trim_bed.exists() ? trim_bed : file("NO_FILE")
            [
                [ id: serotype ],  // meta for reference
                fasta,
                bed,
                trim_bed_path
            ]
        }
        .set { ch_references }

    //
    // MODULE: Create BWA index for each serotype reference
    //
    ch_references
        .map { meta, fasta, bed, trim_bed -> [ meta, fasta ] }
        .set { ch_fasta_for_index }

    BWA_INDEX (
        ch_fasta_for_index
    )
    ch_versions = ch_versions.mix(BWA_INDEX.out.versions.first())

    //
    // Prepare reference channels with index
    //
    BWA_INDEX.out.index
        .join(ch_references.map { meta, fasta, bed, trim_bed -> [ meta, fasta, bed, trim_bed ] })
        .map { meta, index, fasta, bed, trim_bed ->
            [ meta, index, fasta, bed, trim_bed ]
        }
        .set { ch_indexed_references }

    //
    // Cross samples with serotypes to create all combinations
    //
    ch_samplesheet
        .combine(ch_indexed_references)
        .map { sample_meta, reads, ref_meta, index, fasta, bed, trim_bed ->
            def new_meta = sample_meta + [ serotype: ref_meta.id ]
            [
                new_meta,    // sample meta with serotype
                reads,       // sample reads
                ref_meta,    // reference meta
                index,       // bwa index
                fasta,       // reference fasta
                bed,         // primer bed
                trim_bed     // trim bed (optional)
            ]
        }
        .set { ch_sample_serotype_combinations }

    //
    // Prepare channels for subworkflow inputs
    // Key all channels by serotype to enable proper joining
    //
    ch_sample_serotype_combinations
        .map { meta, reads, ref_meta, index, fasta, bed, trim_bed ->
            [ meta, reads ]
        }
        .set { ch_reads }

    // Key reference channels by serotype ID for joining in subworkflow
    ch_sample_serotype_combinations
        .map { meta, reads, ref_meta, index, fasta, bed, trim_bed ->
            [ meta.serotype, index ]
        }
        .unique()
        .set { ch_bwa_index }

    ch_sample_serotype_combinations
        .map { meta, reads, ref_meta, index, fasta, bed, trim_bed ->
            [ meta.serotype, fasta ]
        }
        .unique()
        .set { ch_reference_fasta }

    ch_sample_serotype_combinations
        .map { meta, reads, ref_meta, index, fasta, bed, trim_bed ->
            [ meta.serotype, bed ]
        }
        .unique()
        .set { ch_primer_bed }

    ch_sample_serotype_combinations
        .map { meta, reads, ref_meta, index, fasta, bed, trim_bed ->
            [ meta.serotype, trim_bed ]
        }
        .unique()
        .set { ch_trim_bed }

    //
    // SUBWORKFLOW: Run DENV serotype analysis for each sample×serotype
    //
    DENV_SEROTYPE_ANALYSIS (
        ch_reads,
        ch_bwa_index,
        ch_reference_fasta,
        ch_primer_bed,
        ch_trim_bed,
        params.min_depth,
        params.consensus_threshold,
        params.variant_threshold,
        params.coverage_threshold,
        params.isnv_min_freq,
        params.isnv_max_freq,
        params.read_cap
    )
    ch_versions = ch_versions.mix(DENV_SEROTYPE_ANALYSIS.out.versions)

    //
    // Collect all serotype calls for summarization
    //
    DENV_SEROTYPE_ANALYSIS.out.serotype_call
        .map { meta, tsv -> tsv }
        .collect()
        .set { ch_all_serotype_calls }

    DENV_SEROTYPE_ANALYSIS.out.variants
        .map { meta, tsv -> tsv }
        .collect()
        .set { ch_all_variants }

    //
    // MODULE: Summarize results across all samples
    //
    SUMMARIZE_RESULTS (
        ch_all_serotype_calls,
        ch_all_variants,
        params.coverage_threshold
    )
    ch_versions = ch_versions.mix(SUMMARIZE_RESULTS.out.versions)

    //
    // MODULE: Generate QC plots (optional)
    //
    if (!params.skip_qc) {
        // Extract Ct data from samplesheet meta and create TSV
        ch_samplesheet
            .filter { meta, reads -> meta.ct != null }
            .map { meta, reads -> "${meta.id}\t${meta.ct}" }
            .collect()
            .map { lines ->
                def content = "sample_id\tct\n" + lines.join("\n")
                content
            }
            .collectFile(name: 'ct_data.tsv', newLine: false, storeDir: "${params.outdir}/pipeline_info")
            .ifEmpty { file("NO_FILE") }
            .set { ch_ct_data }

        QC_PLOTS (
            SUMMARIZE_RESULTS.out.serotype_calls,
            SUMMARIZE_RESULTS.out.variants_summary,
            ch_ct_data
        )
        ch_versions = ch_versions.mix(QC_PLOTS.out.versions)
    }

    //
    // Route QC outputs to MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(
        DENV_SEROTYPE_ANALYSIS.out.ivar_trim_log.collect{it[1]}
    )
    ch_multiqc_files = ch_multiqc_files.mix(
        DENV_SEROTYPE_ANALYSIS.out.samtools_stats.collect{it[1]}
    )
    ch_multiqc_files = ch_multiqc_files.mix(
        DENV_SEROTYPE_ANALYSIS.out.flagstat.collect{it[1]}
    )
    ch_multiqc_files = ch_multiqc_files.mix(
        DENV_SEROTYPE_ANALYSIS.out.nextclade_csv.collect{it[1]}
    )

    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .filter { it && it.trim() && it.trim() != '{}' }  // Filter empty entries
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'denver_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList()
    versions       = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
