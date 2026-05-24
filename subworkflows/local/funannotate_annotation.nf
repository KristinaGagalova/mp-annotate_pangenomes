//
// Complete funannotate annotation workflow
//

include { FUNANNOTATE_PREDICT }  from '../../modules/local/funannotate_predict'
include { FUNANNOTATE_ANNOTATE } from '../../modules/local/funannotate_annotate'

workflow FUNANNOTATE_ANNOTATION {
    take:
    ch_cleaned_genomes  // channel: [meta, path(genome)]
    ch_transcripts      // channel: path(transcripts)
    database            // val: database

    main:
    ch_versions = Channel.empty()

    // Derive the --name value: base name of the fasta without extension, suffixed with '_'
    ch_predict_input = ch_cleaned_genomes.map { meta, genome ->
        def base_name = genome.baseName + '_'
        [meta, genome, base_name]
    }

    // Gene prediction
    FUNANNOTATE_PREDICT(
        ch_predict_input,
        ch_transcripts.first(),
        database
    )
    ch_versions = ch_versions.mix(FUNANNOTATE_PREDICT.out.versions)

    // Functional annotation
    FUNANNOTATE_ANNOTATE(
        FUNANNOTATE_PREDICT.out.predict_results,
        FUNANNOTATE_PREDICT.out.genome,
        FUNANNOTATE_PREDICT.out.annotations,
        database
    )
    ch_versions = ch_versions.mix(FUNANNOTATE_ANNOTATE.out.versions)

    emit:
    predict_results    = FUNANNOTATE_PREDICT.out.predict_results
    genome            = FUNANNOTATE_PREDICT.out.genome
    annotations       = FUNANNOTATE_PREDICT.out.annotations
    annotated_results = FUNANNOTATE_ANNOTATE.out.annotated_results
    versions          = ch_versions
}
