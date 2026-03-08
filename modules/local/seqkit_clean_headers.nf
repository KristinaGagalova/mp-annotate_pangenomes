process SEQKIT_CLEAN_HEADERS {

    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0':
        'quay.io/biocontainers/seqkit:2.9.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*_clean.fasta"), emit: cleaned_results
    tuple val(meta), path("*_header_mapping.tsv"), emit: mapping_tab
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqkit replace -p '[|:/\\s]' -r '_' ${fasta} ${args} > ${prefix}_clean.fasta

    seqkit fx2tab ${fasta} | cut -f1 > original_headers.txt
    seqkit fx2tab ${prefix}_clean.fasta | cut -f1 > cleaned_headers.txt
    paste original_headers.txt cleaned_headers.txt > ${prefix}_header_mapping.tsv
    rm original_headers.txt cleaned_headers.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_clean.fasta
    touch ${prefix}_header_mapping.tsv
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit:
    END_VERSIONS
    """
}
