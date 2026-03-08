process FUNANNOTATE_CLEAN {

    tag "$meta.id"
    label 'process_medium'
    
    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*_cleaned.fasta"), emit: cleaned_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    funannotate clean \\
        -i ${fasta} \\
        -o ${prefix}_cleaned.fasta \\
        --cpus ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: \$(funannotate --version 2>&1 | grep -oP 'funannotate v\\K[0-9.]+')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_cleaned.fasta
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate:
    END_VERSIONS
    """
}
