//
// Gene prediction using BRAKER3
//
include { STAR_GENOMEGENERATE } from '../../modules/nf-core/star/genomegenerate/main'
include { STAR_ALIGN }          from '../../modules/nf-core/star/align/main'
include { BRAKER3 }             from '../../modules/nf-core/braker3/main'

workflow BRAKER3_GENE_PREDICTION {
    take:
    ch_genomes          // channel: [meta, path(genome)]
    ch_reads            // channel: [meta, path(reads)] or empty
    ch_gtf              // channel: [meta, path(gtf)] or empty
    ch_proteins         // channel: path(proteins) or empty
    ch_hintsfile        // channel: path(hintsfile) or empty
    ch_rnaseq_sets_dirs // channel: path(rnaseq_sets_dirs) or empty
    ch_rnaseq_sets_ids  // channel: path(rnaseq_sets_ids) or empty

    main:
    ch_versions = Channel.empty()

    // Split reads into zipped and unzipped before passing to STAR
    ch_reads_gz = ch_reads.filter { meta, reads ->
        def readList = reads instanceof List ? reads : [reads]
        readList.every { it.name.endsWith('.fastq.gz') || it.name.endsWith('.fq.gz') }
    }
    ch_reads_unzipped = ch_reads.filter { meta, reads ->
        def readList = reads instanceof List ? reads : [reads]
        readList.any { it.name.endsWith('.fastq') || it.name.endsWith('.fq') }
    }
    ch_reads_for_star = ch_reads_gz.mix(ch_reads_unzipped)

    // RNA-seq mapping: build STAR index then align reads → BAMs for BRAKER3
    if (params.reads_for_mapping) {

        // Build GTF channel for STAR genome generation:
        // If a GTF was provided use it, otherwise create a dummy [meta, []] tuple.
        // STAR_GENOMEGENERATE accepts an empty list for the GTF path (optional input).
        ch_gtf_for_index = ch_gtf
            .map { meta, gtf -> tuple(meta, gtf) }
            .ifEmpty( [ [id: 'no_gtf'], [] ] )
            .first()

        STAR_GENOMEGENERATE (
            ch_genomes,
            ch_gtf_for_index
        )
        ch_versions = ch_versions.mix(STAR_GENOMEGENERATE.out.versions_star)

        ch_reads_index = ch_reads_for_star.combine(STAR_GENOMEGENERATE.out.index)

        STAR_ALIGN (
            ch_reads_index.map { it -> tuple(it[0], it[1]) },  // [meta, reads]
            ch_reads_index.map { it -> tuple(it[2], it[3]) },  // [meta2, index]
            ch_gtf_for_index,
            false   // star_ignore_sjdbgtf
        )
        ch_versions = ch_versions.mix(STAR_ALIGN.out.versions_star)

        ch_bam_input = STAR_ALIGN.out.bam_sorted
            .map  { it -> it[1] }
            .collect()

        ch_bam_emit   = STAR_ALIGN.out.bam_sorted
        ch_fastq_emit = STAR_ALIGN.out.fastq

    } else {
        ch_bam_input  = Channel.value([])
        ch_bam_emit   = Channel.empty()
        ch_fastq_emit = Channel.empty()
    }

    // Resolve optional BRAKER3 inputs — toList() on an empty channel emits []
    ch_proteins_input         = ch_proteins.toList()
    ch_hintsfile_input        = ch_hintsfile.toList()
    ch_rnaseq_sets_dirs_input = ch_rnaseq_sets_dirs.toList()
    ch_rnaseq_sets_ids_input  = ch_rnaseq_sets_ids.toList()

    // Combine all inputs per genome
    // Index layout:
    //   it[0] = meta
    //   it[1] = genome
    //   it[2] = bam              ([] when not mapping)
    //   it[3] = rnaseq_sets_dirs ([] when absent)
    //   it[4] = rnaseq_sets_ids  ([] when absent)
    //   it[5] = proteins         ([] when absent)
    //   it[6] = hintsfile        ([] when absent)
    ch_braker3_input = ch_genomes
        .combine( ch_bam_input )
        .combine( ch_rnaseq_sets_dirs_input )
        .combine( ch_rnaseq_sets_ids_input )
        .combine( ch_proteins_input )
        .combine( ch_hintsfile_input )

    BRAKER3 (
        ch_braker3_input.map { it -> tuple(it[0], it[1]) },
        ch_braker3_input.map { it -> it[2] },
        ch_braker3_input.map { it -> it[3] },
        ch_braker3_input.map { it -> it[4] },
        ch_braker3_input.map { it -> it[5] },
        ch_braker3_input.map { it -> it[6] }
    )
    ch_versions = ch_versions.mix(BRAKER3.out.versions)

    emit:
    gtf         = BRAKER3.out.gtf
    cds         = BRAKER3.out.cds
    aa          = BRAKER3.out.aa
    hintsfile   = BRAKER3.out.hintsfile
    gff3        = BRAKER3.out.gff3
    citations   = BRAKER3.out.citations
    bam         = ch_bam_emit
    fastq       = ch_fastq_emit
    fastq_input = ch_reads_for_star
    versions    = ch_versions
}

