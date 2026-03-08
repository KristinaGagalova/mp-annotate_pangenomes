//
// Complete funannotate annotation workflow
//

include { FUNANNOTATE_PREDICT }  from '../../modules/local/funannotate_predict'
include { FUNANNOTATE_ANNOTATE } from '../../modules/local/funannotate_annotate'

workflow FUNANNOTATE_ANNOTATION {
    take:
    ch_cleaned_genomes  // channel: [meta, path(genome)]
    ch_transcripts      // channel: path(transcripts)
    ch_database         // channel: path(database)

    main:
    ch_versions = Channel.empty()

    // Gene prediction
    FUNANNOTATE_PREDICT(
        ch_cleaned_genomes,
        ch_transcripts.first(),
        ch_database
    )
    ch_versions = ch_versions.mix(FUNANNOTATE_PREDICT.out.versions)

    // Functional annotation
    FUNANNOTATE_ANNOTATE(
        FUNANNOTATE_PREDICT.out.predict_results,
        FUNANNOTATE_PREDICT.out.genome,
        FUNANNOTATE_PREDICT.out.annotations,
        ch_database
    )
    ch_versions = ch_versions.mix(FUNANNOTATE_ANNOTATE.out.versions)

    emit:
    predict_results    = FUNANNOTATE_PREDICT.out.predict_results
    genome            = FUNANNOTATE_PREDICT.out.genome
    annotations       = FUNANNOTATE_PREDICT.out.annotations
    annotated_results = FUNANNOTATE_ANNOTATE.out.annotated_results
    versions          = ch_versions
}
