//
// Preprocess genome sequences for annotation
//

include { SEQKIT_CLEAN_HEADERS } from '../../modules/local/seqkit_clean_headers'
include { FUNANNOTATE_CLEAN }    from '../../modules/local/funannotate_clean'

workflow GENOME_PREPROCESSING {
    take:
    ch_genomes // channel: [meta, path(genome)]

    main:
    ch_versions = Channel.empty()

    // Clean headers
    SEQKIT_CLEAN_HEADERS(ch_genomes)
    ch_versions = ch_versions.mix(SEQKIT_CLEAN_HEADERS.out.versions)

    // Clean genomes with funannotate
    FUNANNOTATE_CLEAN(SEQKIT_CLEAN_HEADERS.out.cleaned_results)
    ch_versions = ch_versions.mix(FUNANNOTATE_CLEAN.out.versions)

    emit:
    cleaned_genomes = FUNANNOTATE_CLEAN.out.cleaned_results
    header_mapping  = SEQKIT_CLEAN_HEADERS.out.mapping_tab
    versions        = ch_versions
}
