process QC_PLOTS {
    tag "plots"
    label 'process_single'

    // TODO: Update container when DENV Python container is available
    container 'placeholder'

    input:
    path(serotype_calls)
    path(variants_summary)
    path(ct_file)
    val(ct_column)
    val(id_column)

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
