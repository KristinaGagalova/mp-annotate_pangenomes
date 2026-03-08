process FUNANNOTATE_SETUP_DB {
    tag "database_setup"
    label 'process_medium'
    
    output:
    path "funannotate_db", emit: database
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    export FUNANNOTATE_DB=funannotate_db
    mkdir -p funannotate_db
    
    funannotate setup -w -d funannotate_db -i all --force ${args}
    funannotate setup -w -d funannotate_db -b fungi --force
    funannotate setup -w -d funannotate_db -b eukaryota --force
    funannotate setup -w -d funannotate_db -b ascomycota --force
    
    funannotate database

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: \$(funannotate --version 2>&1 | grep -oP 'funannotate v\\K[0-9.]+')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p funannotate_db
    touch funannotate_db/database_ready.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        funannotate: 
    END_VERSIONS
    """
}
