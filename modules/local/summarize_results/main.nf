process SUMMARIZE_RESULTS {
    tag "summary"
    label 'process_single'

    container '025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-python:3.12-den_478b5ab_20251221'

    input:
    path(serotype_calls)
    path(variant_counts)

    output:
    path("serotype_calls.tsv")    , emit: serotype_calls
    path("top_calls.tsv")         , emit: top_calls
    path("all_info.tsv")          , emit: all_info
    path("low_coverage_calls.csv"), emit: low_coverage
    path("variants_summary.tsv")  , emit: variants_summary
    path("versions.yml")          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'summarize_results.py'

    stub:
    """
    touch serotype_calls.tsv
    touch top_calls.tsv
    touch all_info.tsv
    touch low_coverage_calls.csv
    touch variants_summary.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | cut -d' ' -f2)
    END_VERSIONS
    """
}
