//
// Setup or validate funannotate database
//

include { FUNANNOTATE_SETUP_DB } from '../../modules/local/funannotate_setup_db'

workflow DATABASE_SETUP {
    take:
    ch_database_dir

    main:
    ch_versions = Channel.empty()

    if (params.database_dir) {
        println "[INFO] Using existing database at: ${params.database_dir}"
        ch_database = ch_database_dir
    } else {
        println "[INFO] Setting up new funannotate database..."
        FUNANNOTATE_SETUP_DB()
        ch_database = FUNANNOTATE_SETUP_DB.out.database_dir
        ch_versions = ch_versions.mix(FUNANNOTATE_SETUP_DB.out.versions)
    }

    emit:
    database = ch_database
    versions  = ch_versions
}
