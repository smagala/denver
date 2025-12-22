process NEXTCLADE_ALIGN {
    tag "${meta.id}"
    label 'process_single'
    container '025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-nextclade:3.18.1-cli_f556ccb_20251220'

    input:
    tuple val(meta), path(consensus)
    path(reference)

    output:
    tuple val(meta), path("*.aln.fasta"), emit: alignment
    path("versions.yml")               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    nextclade run \\
        ${args} \\
        --input-ref ${reference} \\
        --output-fasta ${prefix}.aln.fasta \\
        ${consensus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade: \$(nextclade --version 2>&1 | sed 's/^nextclade //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.aln.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade: \$(nextclade --version 2>&1 | sed 's/^nextclade //')
    END_VERSIONS
    """
}
