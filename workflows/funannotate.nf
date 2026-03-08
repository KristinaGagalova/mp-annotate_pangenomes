/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { TRANSCRIPT_PREPARATION }  from '../subworkflows/local/transcript_preparation'
include { GENOME_PREPROCESSING }    from '../subworkflows/local/genome_preprocessing'
include { DATABASE_SETUP }          from '../subworkflows/local/database_setup'
include { FUNANNOTATE_ANNOTATION }  from '../subworkflows/local/funannotate_annotation'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow FUNANNOTATE {
    take:
    ch_input // channel: input data

    main:
    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Prepare transcript evidence
    //
    ch_reads = params.reads ? Channel.fromPath(params.reads) : Channel.empty()
    ch_transcripts = params.transcripts ? Channel.fromPath(params.transcripts) : Channel.empty()
    
    TRANSCRIPT_PREPARATION(
        ch_reads,
        ch_transcripts
    )
    ch_versions = ch_versions.mix(TRANSCRIPT_PREPARATION.out.versions)

    //
    // SUBWORKFLOW: Setup database
    //
    ch_database_dir = params.database_dir ? Channel.fromPath(params.database_dir) : Channel.empty()
    
    DATABASE_SETUP(
        ch_database_dir
    )
    ch_versions = ch_versions.mix(DATABASE_SETUP.out.versions)

    //
    // Create genome channel
    //
    ch_genomes = Channel
        .fromPath(params.genomes ?: 'data/genomes/*.fa')
        .map { genome_file ->
            def meta = [:]
            meta.id = genome_file.getBaseName()
            tuple(meta, genome_file)
        }

    //
    // SUBWORKFLOW: Preprocess genomes
    //
    GENOME_PREPROCESSING(
        ch_genomes
    )
    ch_versions = ch_versions.mix(GENOME_PREPROCESSING.out.versions)

    //
    // SUBWORKFLOW: Run funannotate annotation
    //
    FUNANNOTATE_ANNOTATION(
        GENOME_PREPROCESSING.out.cleaned_genomes,
        TRANSCRIPT_PREPARATION.out.transcripts,
        DATABASE_SETUP.out.database
    )
    ch_versions = ch_versions.mix(FUNANNOTATE_ANNOTATION.out.versions)

    emit:
    predict_results    = FUNANNOTATE_ANNOTATION.out.predict_results
    genome            = FUNANNOTATE_ANNOTATION.out.genome
    annotations       = FUNANNOTATE_ANNOTATION.out.annotations
    annotated_results = FUNANNOTATE_ANNOTATION.out.annotated_results
    versions          = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
