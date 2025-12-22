process QC_PLOTS {
    tag "plots"
    label 'process_single'

    container '025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-python:3.12-den_478b5ab_20251221'

    input:
    path(serotype_calls)
    path(variants_summary)
    path(ct_data)  // TSV with sample_id and ct columns, or empty file

    output:
    path("variant_plot.pdf"), emit: variant_plot
    path("ct_plot.pdf")     , emit: ct_plot, optional: true
    path("versions.yml")    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'qc_plots.py'

    stub:
    """
    touch variant_plot.pdf
    touch ct_plot.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | cut -d' ' -f2)
        matplotlib: \$(python -c "import matplotlib; print(matplotlib.__version__)")
    END_VERSIONS
    """
}
