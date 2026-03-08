//
// Prepare transcript evidence for gene prediction
//

include { RNABLOOM_ASSEMBLE }                from '../../modules/local/rnabloom_assemble'
include { CONCAT_DEDUPLICATE_TRANSCRIPTS }   from '../../modules/local/concatenate_assembled_transcripts'

workflow TRANSCRIPT_PREPARATION {
    take:
    ch_reads        // channel: path(reads_list) or empty
    ch_transcripts  // channel: path(transcripts) or empty

    main:
    ch_versions = Channel.empty()

    // Handle transcript evidence
    if (params.reads && !params.transcripts) {
        RNABLOOM_ASSEMBLE(ch_reads)
        
        // If RNABLOOM produces multiple output files, collect them
        ch_transcript_files = RNABLOOM_ASSEMBLE.out.transcripts
        ch_versions = ch_versions.mix(RNABLOOM_ASSEMBLE.out.versions)
        
        // Concatenate and deduplicate transcripts
        CONCAT_DEDUPLICATE_TRANSCRIPTS(ch_transcript_files)
        ch_transcript_evidence = CONCAT_DEDUPLICATE_TRANSCRIPTS.out.transcripts
        ch_versions = ch_versions.mix(CONCAT_DEDUPLICATE_TRANSCRIPTS.out.versions)

    } else if (params.transcripts) {
        // Handle multiple transcript files if provided as a pattern
        ch_transcript_files = Channel.fromPath(params.transcripts)
        
        // Check if we have multiple files to concatenate
        ch_transcript_files
            .collect()
            .map { files -> 
                if (files.size() > 1) {
                    return files
                } else {
                    return null
                }
            }
            .set { ch_multiple_transcripts }
        
        // If multiple files, concatenate and deduplicate
        ch_multiple_transcripts
            .filter { it != null }
            .ifEmpty { Channel.empty() }
            .set { ch_to_concat }
            
        if (!ch_to_concat.isEmpty()) {
            CONCAT_DEDUPLICATE_TRANSCRIPTS(ch_to_concat.first())
            ch_transcript_evidence = CONCAT_DEDUPLICATE_TRANSCRIPTS.out.transcripts
            ch_versions = ch_versions.mix(CONCAT_DEDUPLICATE_TRANSCRIPTS.out.versions)
        } else {
            // Single file, use as is
            ch_transcript_evidence = ch_transcript_files.first()
        }

    } else {
        error "You must provide either --reads or --transcripts"
    }

    emit:
    transcripts = ch_transcript_evidence
    versions    = ch_versions
}
