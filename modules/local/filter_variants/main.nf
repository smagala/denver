process FILTER_VARIANTS {
    tag "${meta.id}"
    label 'process_single'

    container '025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-python:3.12-den_478b5ab_20251221'

    input:
    tuple val(meta), path(variants)
    val(isnv_min_freq)
    val(isnv_max_freq)

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
