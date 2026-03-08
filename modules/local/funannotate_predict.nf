process FUNANNOTATE_PREDICT {

    tag "$meta.id"
    label 'process_high'
    
    input:
    tuple val(meta), path(genome_fasta)
    path transcript_fasta
    path database

    output:
    tuple val(meta), path("funannotate_output"), emit: predict_results
    tuple val(meta), path("funannotate_output/predict_results/*.scaffolds.fa"), emit: genome
    tuple val(meta), path("funannotate_output/predict_results/*.gff3"), emit: annotations
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    export FUNANNOTATE_DB=${database}
    funannotate database
    
    mkdir -p funannotate_output
    funannotate predict \\
        -i $genome_fasta \\
        -o funannotate_output \\
        --transcript_evidence $transcript_fasta \\
        --species "${params.species}" \\
        --strain ${prefix} \\
        --cpus ${task.cpus} \\
        --busco_seed_species ${params.buscoseed} \\
        --busco_db ${params.buscodb} \\
        --organism ${params.organism} \\
        --ploidy ${params.ploidy} \\
        --header_length 30 \\
        --min_training_models 100 \\
        --force \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: \$(funannotate --version 2>&1 | grep -oP 'funannotate v\\K[0-9.]+')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p funannotate_output/predict_results
    touch funannotate_output/predict_results/${prefix}.scaffolds.fa
    touch funannotate_output/predict_results/${prefix}.gff3
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate:
    END_VERSIONS
    """
}
