process NEXTCLADE_ALIGN {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'oamd-bio-nextclade:3.18.1_5095e76_v0'

    input:
    tuple val(meta), path(consensus)
    path(reference)

    output:
    tuple val(meta), path("${prefix}.aln.fasta")      , emit: alignment
    tuple val(meta), path("${prefix}.nextclade.csv")   , emit: csv
    path "versions.yml"                                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    nextclade \\
        run \\
        $args \\
        --jobs $task.cpus \\
        --input-ref ${reference} \\
        --output-fasta ${prefix}.aln.fasta \\
        --output-csv ${prefix}.nextclade.csv \\
        ${consensus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade: \$(echo \$(nextclade --version 2>&1) | sed 's/^.*nextclade //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.aln.fasta
    echo "seqName;clade;qc.overallScore;qc.overallStatus" > ${prefix}.nextclade.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade: \$(echo \$(nextclade --version 2>&1) | sed 's/^.*nextclade //; s/ .*\$//')
    END_VERSIONS
    """
}
