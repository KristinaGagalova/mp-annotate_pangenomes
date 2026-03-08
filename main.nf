#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FUNANNOTATE } from './workflows/funannotate'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow FUNANNOTATE_PIPELINE {
    take:
    ch_input // channel: input data

    main:

    //
    // WORKFLOW: Run pipeline
    //
    FUNANNOTATE (
        ch_input
    )

    emit:
    predict_results    = FUNANNOTATE.out.predict_results
    genome            = FUNANNOTATE.out.genome
    annotations       = FUNANNOTATE.out.annotations
    annotated_results = FUNANNOTATE.out.annotated_results
    versions          = FUNANNOTATE.out.versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // Create input channel
    //
    ch_input = Channel.empty()
    
    if (params.reads) {
        ch_input = Channel.fromPath(params.reads)
    } else if (params.transcripts) {
        ch_input = Channel.fromPath(params.transcripts)
    }

    //
    // WORKFLOW: Run main workflow
    //
    FUNANNOTATE_PIPELINE (
        ch_input
    )

    //
    // Collect and display results
    //
    FUNANNOTATE_PIPELINE.out.versions.view { "Software versions: $it" }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
