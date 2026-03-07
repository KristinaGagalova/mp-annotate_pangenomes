#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.reads = null
params.transcripts = null
params.genomes = null // Allow passing a file list via --genomes (optional)
params.database_dir = null // If provided, skip database setup and use existing database
// params.genemark_dir = null

// Funannotate-specific parameters
params.buscoseed = 'anidulans' // Augustus pre-trained species to start BUSCO. Default: anidulans
params.species = "Ascomycota"
params.buscodb = 'fungi'
params.organism = 'fungus'
params.ploidy = 1

process RNABLOOM_ASSEMBLE {

    tag "rnabloom_assembly"
    publishDir "results/rnabloom", mode: 'copy'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/rnabloom:2.0.0--hdfd78af_0':
        'quay.io/biocontainers/rnabloom:2.0.0--hdfd78af_0' }"

    input:
    path reads_list

    output:
    path "rnabloom_output/rnabloom.transcripts.fa", emit: transcripts

    script:
    """
    mkdir -p rnabloom_output

    java -Xmx200g -jar RNA-Bloom.jar \\
        -pool ${reads_list} \\
        -revcomp-right \\
        -t ${task.cpus} \\
        -outdir rnabloom_output \\
	-fpr 0.01
    """
}

process FUNANNOTATE_SETUP_DB {

    tag "database_setup"
    publishDir "funannotate_db_new", mode: 'copy'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'nextgenusfs/funannotate:v1.8.17':
        'https://depot.galaxyproject.org/singularity/funannotate:1.8.17--pyhdfd78af_5' }"

    output:
    path "funannotate_db", emit: database

    script:
    """
    # Set the database environment variable
    export FUNANNOTATE_DB=funannotate_db
    
    # Create database directory
    mkdir -p funannotate_db
    
    # Download and setup all funannotate databases
    funannotate setup -w -d funannotate_db -i all --force
    
    # Specifically install the fungi BUSCO database
    funannotate setup -w -d funannotate_db -b fungi --force
    
    # Also install other common BUSCO databases that might be useful
    funannotate setup -w -d funannotate_db -b eukaryota --force
    funannotate setup -w -d funannotate_db -b ascomycota --force
    
    # Verify database installation
    funannotate database
    """
}

process FUNANNOTATE_PREDICT {

    tag "$sample_id"
    publishDir "results/funannotate/${sample_id}/predict", mode: 'copy'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'nextgenusfs/funannotate:v1.8.17':
        'https://depot.galaxyproject.org/singularity/funannotate:1.8.17--pyhdfd78af_5' }"

    input:
    tuple val(sample_id), path(genome_fasta)
    path transcript_fasta
    val database

    output:
    tuple val(sample_id), path("funannotate_output")                               , emit: predict_results
    tuple val(sample_id), path("funannotate_output/predict_results/*.scaffolds.fa"), emit: genome
    tuple val(sample_id), path("funannotate_output/predict_results/*.gff3")        , emit: annotations

    script:
    """
    # Set the database environment variable
    export FUNANNOTATE_DB=${database}
    
    # Verify BUSCO database is available
    funannotate database
    
    # Check if fungi database exists
    
    mkdir -p funannotate_output
    funannotate predict \\
        -i $genome_fasta \\
        -o funannotate_output \\
        --transcript_evidence $transcript_fasta \\
        --species "${params.species}" \\
        --strain $sample_id \\
        --cpus ${task.cpus} \\
        --busco_seed_species ${params.buscoseed} \\
        --busco_db ${params.buscodb} \\
        --organism ${params.organism} \\
        --ploidy ${params.ploidy} \\
	--header_length 30 \\
        --min_training_models 100 \\
        --force
    """
}


process FUNANNOTATE_CLEAN {

    tag "$sample_id"
    publishDir "results/funannotate/${sample_id}/clean", mode: 'copy'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'nextgenusfs/funannotate:v1.8.17':
        'https://depot.galaxyproject.org/singularity/funannotate:1.8.17--pyhdfd78af_5' }"

    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("${sample_id}_cleaned.fasta"), emit: cleaned_results

    script:
    """
    # Run sort and clean step
    funannotate clean \\
        -i ${fasta} \\
        -o ${sample_id}_cleaned.fasta \\
        --cpus ${task.cpus}
    """
}


process SEQKIT_CLEAN_HEADERS {

    tag "$sample_id"
    publishDir "results/funannotate/${sample_id}/clean_head", mode: 'copy'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0':
        'quay.io/biocontainers/seqkit:2.9.0--h9ee0642_0' }"

    input:
    tuple val(sample_id), path(fasta)

    output:
    tuple val(sample_id), path("${sample_id}_clean.fasta")   , emit: cleaned_results
    tuple val(sample_id), path("${sample_id}_header_mapping.tsv"), emit: mapping_tab

    script:
    """
    seqkit replace -p '[|:/\s]' -r '_' ${fasta} > ${sample_id}_clean.fasta

    # create a mapping report
    seqkit fx2tab ${sample_id}_clean.fasta | cut -f1 > original_headers.txt
    seqkit fx2tab ${sample_id}_clean.fasta | cut -f1 > cleaned_headers.txt
    paste original_headers.txt cleaned_headers.txt > ${sample_id}_header_mapping.tsv
    rm original_headers.txt cleaned_headers.txt
    """
}


process FUNANNOTATE_ANNOTATE {

    tag "$sample_id"
    publishDir "results/funannotate/${sample_id}/annotate", mode: 'copy'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'nextgenusfs/funannotate:v1.8.17':
        'https://depot.galaxyproject.org/singularity/funannotate:1.8.17--pyhdfd78af_5' }"

    input:
    tuple val(sample_id), path(annotated_output)
    tuple val(sample_id), path(annotated_fasta)
    tuple val(sample_id), path(annotations)
    val database

    output:
    tuple val(sample_id), path("functional_annotations"), emit: annotated_results

    script:
    """
    # Set the database environment variable
    export FUNANNOTATE_DB=${database}
    
    # Run functional annotation
    echo "[INFO] Running funannotate annotate for sample: ${sample_id}"
    funannotate annotate \\
        --gff ${annotations} \\
        --fasta ${annotated_fasta} \\
        --out functional_annotations \\
        --species ${params.species} \\
        --cpus ${task.cpus} \\
	--header_length 30
    """
}

workflow {

    // Conditional transcript handling
    if (params.reads) {
        
        // Create reads list channel
        reads_ch = Channel.fromPath(params.reads)        
        RNABLOOM_ASSEMBLE(reads_ch)
        transcript_fasta = RNABLOOM_ASSEMBLE.out.transcripts
        
    } else if (params.transcripts) {
        // Use provided transcript file
        println "[INFO] Using provided transcript file: ${params.transcripts}"
        transcript_fasta = Channel.fromPath(params.transcripts)
        
    } else {
        error "You must provide either --reads <reads.tsv> or --transcripts <transcript.fa>"
    }

    // Conditional database setup
    if (params.database_dir) {
        // Use existing database
        println "[INFO] Using existing database at: ${params.database_dir}"
        database_ch = Channel.fromPath(params.database_dir, checkIfExists: true)
    } else {
        // Setup funannotate database
        println "[INFO] No database_dir provided, setting up new database..."
        FUNANNOTATE_SETUP_DB()
        database_ch = FUNANNOTATE_SETUP_DB.out.database
    }

    // Create channel with correct structure: [sample_id, path(genome)]
    genomes_ch = Channel
        .fromPath(params.genomes ?: 'data/genomes/*.fa')
        .map { genome_file ->
            def sample_id = genome_file.getBaseName()
            tuple(sample_id, genome_file)
        }

    // Run sort and clean step
    SEQKIT_CLEAN_HEADERS(genomes_ch)
    FUNANNOTATE_CLEAN(SEQKIT_CLEAN_HEADERS.out.cleaned_results)    

    // Run gene prediction
    FUNANNOTATE_PREDICT(FUNANNOTATE_CLEAN.out.cleaned_results,
                        transcript_fasta.first(),
                        database_ch)
    
    // Run functional annotation
    FUNANNOTATE_ANNOTATE(FUNANNOTATE_PREDICT.out.predict_results, 
                        FUNANNOTATE_PREDICT.out.genome,
                        FUNANNOTATE_PREDICT.out.annotations,
                        database_ch)
}
