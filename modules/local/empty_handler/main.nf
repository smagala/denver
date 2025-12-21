process EMPTY_HANDLER {
    tag "${meta.id}"
    label 'process_single'

    // TODO: Update container when DENV Python container is available
    container 'placeholder'

    input:
    tuple val(meta), val(virus_type)
    val(depth)

    output:
    tuple val(meta), path("*_all_virustype_info.txt"), emit: virustype_info
    tuple val(meta), path("*.variants.tsv")          , emit: variants
    path("versions.yml")                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'empty_handler.py'

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_all_virustype_info.txt
    touch ${prefix}.${virus_type}.${depth}.variants.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | cut -d' ' -f2)
    END_VERSIONS
    """
}
