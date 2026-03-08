process RNABLOOM_ASSEMBLE {

    tag "rnabloom_assembly"
    label 'process_high'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
       'https://depot.galaxyproject.org/singularity/rnabloom:2.0.0--hdfd78af_0':
       'quay.io/biocontainers/rnabloom:2.0.0--hdfd78af_0' }"

    input:
    path reads_list

    output:
    path "concatenated_transcripts.fa", emit: transcripts
    path "rnabloom_output", emit: rnabloom_dir
    path "assembly_stats.txt", emit: stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    export JAVA_TOOL_OPTIONS="-Xmx200g"
    mkdir -p rnabloom_output

    # Run RNABloom
    rnabloom \\
        -pool ${reads_list} \\
        -revcomp-right \\
        -t ${task.cpus} \\
        -outdir rnabloom_output \\
        -fpr 0.01 \\
        ${args}

    # find output
    fa_files=\$(find rnabloom_output -name "*.transcripts.nr.fa" -type f)
    if [ ! -z "\$fa_files" ]; then
        echo "Found .fa files:" >> assembly_stats.txt
        echo "\$fa_files" >> assembly_stats.txt
        cat \$fa_files > concatenated_transcripts.fa
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rnabloom: \$(rnabloom --version 2>&1 | grep -oP 'RNA-Bloom v\\K[0-9.]+')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p rnabloom_output
    touch concatenated_transcripts.fa
    echo "Stub run - no actual assembly performed" > assembly_stats.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rnabloom:
    END_VERSIONS
    """
}
