#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FUNANNOTATE }       from './workflows/funannotate'
include { BRAKER3_PIPELINE }  from './workflows/braker3'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEFAULT PARAMETERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.run_funannotate = false
params.run_braker3     = false
params.reads           = null
params.transcripts     = null

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run Funannotate analysis pipeline
//
workflow FUNANNOTATE_PIPELINE {
    take:
    ch_input // channel: input data

    main:
    FUNANNOTATE (
        ch_input
    )

    emit:
    predict_results    = FUNANNOTATE.out.predict_results
    genome             = FUNANNOTATE.out.genome
    annotations        = FUNANNOTATE.out.annotations
    annotated_results  = FUNANNOTATE.out.annotated_results
    versions           = FUNANNOTATE.out.versions
}

//
// WORKFLOW: Run BRAKER3 analysis pipeline
//
workflow BRAKER3_MAIN {
    take:
    ch_input // channel: input data

    main:
    BRAKER3_PIPELINE (
        ch_input
    )

    emit:
    gtf       = BRAKER3_PIPELINE.out.gtf
    cds       = BRAKER3_PIPELINE.out.cds
    aa        = BRAKER3_PIPELINE.out.aa
    hintsfile = BRAKER3_PIPELINE.out.hintsfile
    gff3      = BRAKER3_PIPELINE.out.gff3
    citations = BRAKER3_PIPELINE.out.citations
    bam       = BRAKER3_PIPELINE.out.bam
    versions  = BRAKER3_PIPELINE.out.versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    ch_input = Channel.empty()

    if (params.reads) {
        ch_input = Channel.fromPath(params.reads)
    } else if (params.transcripts) {
        ch_input = Channel.fromPath(params.transcripts)
    }

    if (params.run_funannotate && !params.run_braker3) {

        FUNANNOTATE_PIPELINE ( ch_input )

        FUNANNOTATE_PIPELINE.out.versions.view    { "Funannotate software versions: $it" }
        FUNANNOTATE_PIPELINE.out.annotations.view { meta, gff -> "Funannotate annotations for ${meta}: $gff" }

    } else if (params.run_braker3 && !params.run_funannotate) {

        BRAKER3_MAIN ( ch_input )

        BRAKER3_MAIN.out.versions.view { "BRAKER3 software versions: $it" }
        BRAKER3_MAIN.out.gtf.view      { meta, gtf -> "BRAKER3 GTF output for ${meta.id}: $gtf" }

    } else if (params.run_funannotate && params.run_braker3) {

        FUNANNOTATE_PIPELINE ( ch_input )
        BRAKER3_MAIN         ( ch_input )

        FUNANNOTATE_PIPELINE.out.versions.view    { "Funannotate software versions: $it" }
        FUNANNOTATE_PIPELINE.out.annotations.view { meta, gff -> "Funannotate annotations for ${meta}: $gff" }
        BRAKER3_MAIN.out.versions.view            { "BRAKER3 software versions: $it" }
        BRAKER3_MAIN.out.gtf.view                 { meta, gtf -> "BRAKER3 GTF output for ${meta.id}: $gtf" }

    } else {
        error """
        =========================================
        ERROR: No pipeline selected.
        =========================================
        Please specify which pipeline(s) to run:

          --run_braker3       Run BRAKER3 pipeline
          --run_funannotate   Run Funannotate pipeline

        Both can be combined:
          nextflow run main.nf --run_braker3 --run_funannotate
        =========================================
        """
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
