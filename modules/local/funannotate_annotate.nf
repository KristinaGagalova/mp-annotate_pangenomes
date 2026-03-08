process FUNANNOTATE_ANNOTATE {

    tag "$meta.id"
    label 'process_high'
    
    input:
    tuple val(meta), path(annotated_output)
    tuple val(meta), path(annotated_fasta)
    tuple val(meta), path(annotations)
    path database

    output:
    tuple val(meta), path("functional_annotations"), emit: annotated_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    export FUNANNOTATE_DB=${database}
    
    echo "[INFO] Running funannotate annotate for sample: ${meta.id}"
    funannotate annotate \\
        --gff ${annotations} \\
        --fasta ${annotated_fasta} \\
        --out functional_annotations \\
        --species ${params.species} \\
        --cpus ${task.cpus} \\
        --header_length 30 \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: \$(funannotate --version 2>&1 | grep -oP 'funannotate v\\K[0-9.]+')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p functional_annotations
    touch functional_annotations/annotation_complete.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate:
    END_VERSIONS
    """
}
