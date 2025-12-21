process FILTER_VARIANTS {
    tag "${meta.id}"
    label 'process_single'

    // TODO: Update container when DENV Python container is available
    container 'placeholder'

    input:
    tuple val(meta), path(variants)

    output:
    tuple val(meta), path("*_variants_frequency.tsv"), emit: filtered_variants
    path("versions.yml")                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'filter_variants.py'

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_variants_frequency.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | cut -d' ' -f2)
    END_VERSIONS
    """
}
