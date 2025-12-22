process FALCO {
    tag "$meta.id"
    label 'process_single'


    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/falco:1.2.1--h867801b_3':
        'biocontainers/falco:1.2.1--h867801b_3' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.txt") , emit: txt
    path  "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ( reads.toList().size() == 1 ) {
        """
        falco $args --threads $task.cpus ${reads} -D ${prefix}_fastqc_data.txt -S ${prefix}_summary.txt -R ${prefix}_fastqc_report.html

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            falco:\$( falco --version | sed -e "s/falco//g" )
        END_VERSIONS
        """
    } else {
        // Handle paired-end reads by running falco on each file separately
        // This avoids the overwriting issue with multiple input files
        """
        for read_file in ${reads}; do
            read_base=\$(basename "\$read_file" | sed 's/.gz\$//' | sed 's/.fastq\$//' | sed 's/.fq\$//')
            falco $args --threads $task.cpus "\$read_file" \\
                -D "\${read_base}_fastqc_data.txt" \\
                -S "\${read_base}_summary.txt" \\
                -R "\${read_base}_fastqc_report.html"
        done

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            falco:\$( falco --version | sed -e "s/falco//g" )
        END_VERSIONS
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_fastqc_data.txt
    touch ${prefix}_fastqc_report.html
    touch ${prefix}_summary.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        falco: \$( falco --version | sed -e "s/falco v//g" )
    END_VERSIONS
    """
}
