//
// Setup or validate funannotate database
//

include { FUNANNOTATE_SETUP_DB } from '../../modules/local/funannotate_setup_db'

workflow DATABASE_SETUP {
    take:
    ch_database_dir  // val: pre-existing path string, or empty

    main:
    ch_versions = Channel.empty()

    if (params.database_dir) {
        ch_database = Channel.value(params.database_dir)
    } else {
        FUNANNOTATE_SETUP_DB()
        ch_versions = ch_versions.mix(FUNANNOTATE_SETUP_DB.out.versions)
        ch_database = FUNANNOTATE_SETUP_DB.out.database
    }

    emit:
    database = ch_database
    versions = ch_versions
}
