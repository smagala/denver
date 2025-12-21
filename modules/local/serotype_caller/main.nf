process SEROTYPE_CALLER {
    tag "${meta.id}"
    label 'process_single'

    // TODO: Update container when DENV Python container is available
    container 'placeholder'

    input:
    tuple val(meta), path(alignment)
    path(bed_file)

    output:
    tuple val(meta), path("*_serotype_call.tsv"), emit: serotype_call
    tuple val(meta), path("*.trim.aln")         , emit: trimmed_alignment, optional: true
    path("versions.yml")                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'serotype_caller.py'

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_serotype_call.tsv
    touch ${prefix}.trim.aln

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | cut -d' ' -f2)
        biopython: \$(python -c "import Bio; print(Bio.__version__)")
    END_VERSIONS
    """
}
