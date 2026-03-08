/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { BRAKER3_GENE_PREDICTION } from '../subworkflows/local/braker3_gene_prediction'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEFAULT PARAMETERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.genomes           = null
params.reads_for_mapping = null
params.gtf_file          = null
params.protein_sequences = null
params.hints_file        = null
params.rnaseq_sets_dirs  = null
params.rnaseq_sets_ids   = null

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    HELPER FUNCTION: Parse reads samplesheet
    TSV format with header: #name  left  right   (leading # is stripped automatically)
    - paired-end if 'right' column is present and non-empty
    - single-end if 'right' is missing or empty
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def parseReadsSamplesheet(String path) {
    Channel
        .fromPath(path, checkIfExists: true)
        .splitCsv(header: true, sep: '\t', strip: true)
        .map { row ->
            // Strip leading '#' from header keys so '#name' becomes 'name'
            def cleanRow = row.collectEntries { k, v -> [ k.replaceAll(/^#+/, ''), v ] }

            log.info "Samplesheet row: ${cleanRow}"

            if (!cleanRow.containsKey('name') || !cleanRow.containsKey('left')) {
                error "Samplesheet missing required columns.\n" +
                      "Expected tab-separated header: name  left  right\n" +
                      "Found columns: ${cleanRow.keySet().join(', ')}"
            }

            def sample = cleanRow.name?.trim()
            def left   = cleanRow.left?.trim()
            def right  = cleanRow.containsKey('right') ? cleanRow.right?.trim() : ''

            if (!sample) { error "Empty 'name' value in row: ${cleanRow}" }
            if (!left)   { error "Empty 'left' value in row: ${cleanRow}" }

            def paired = right && right != '' && right != 'NA'
            def read1  = file(left,  checkIfExists: true)
            def reads  = paired ? [ read1, file(right, checkIfExists: true) ] : [ read1 ]

            reads.each { f ->
                if (!f.name.endsWith('.fastq.gz') &&
                    !f.name.endsWith('.fq.gz')    &&
                    !f.name.endsWith('.fastq')    &&
                    !f.name.endsWith('.fq')) {
                    error "Unsupported read format: ${f.name}\n" +
                          "Expected: .fastq  .fq  .fastq.gz  .fq.gz"
                }
            }

            def meta        = [:]
            meta.id         = sample
            meta.single_end = !paired

            log.info "Parsed read → id: ${meta.id} | single_end: ${meta.single_end} | files: ${reads*.name}"
            tuple(meta, reads)
        }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow BRAKER3_PIPELINE {
    take:
    ch_input

    main:
    ch_versions = Channel.empty()

    // ── Genomes ───────────────────────────────────────────────────────────────
    def genome_glob = params.genomes ?: 'data/genomes/*.{fa,fasta}'
    log.info "Genome glob: ${genome_glob}"

    ch_genomes = Channel
        .fromPath(genome_glob, checkIfExists: true)
        .filter { f -> f.name.endsWith('.fa') || f.name.endsWith('.fasta') }
        .map { f ->
            def meta = [id: f.name.replaceAll(/\.(fa|fasta)$/, '')]
            log.info "Genome found: ${f.name} → id: ${meta.id}"
            tuple(meta, f)
        }
        .ifEmpty {
            error "No genome files found matching: ${genome_glob}\n" +
                  "Supported extensions: .fa  .fasta"
        }

    ch_genomes.view { meta, f -> "GENOME → ${meta.id} : ${f}" }

    // ── Reads ─────────────────────────────────────────────────────────────────
    log.info "reads_for_mapping param: '${params.reads_for_mapping}'"

    if (params.reads_for_mapping) {
        ch_rna_reads = parseReadsSamplesheet(params.reads_for_mapping as String)
        ch_rna_reads.view { meta, reads ->
            "READS → id: ${meta.id} | single_end: ${meta.single_end} | files: ${reads*.name}"
        }
    } else {
        log.warn "No --reads_for_mapping provided — BRAKER3 will run without RNA-seq BAMs."
        ch_rna_reads = Channel.empty()
    }

    // ── Optional inputs ───────────────────────────────────────────────────────
    ch_gtf = params.gtf_file ?
        Channel.fromPath(params.gtf_file, checkIfExists: true)
               .map { gtf -> tuple([id: 'gtf'], gtf) } :
        Channel.empty()

    ch_proteins = params.protein_sequences ?
        Channel.fromPath(params.protein_sequences, checkIfExists: true) :
        Channel.empty()

    ch_hintsfile = params.hints_file ?
        Channel.fromPath(params.hints_file, checkIfExists: true) :
        Channel.empty()

    ch_rnaseq_sets_dirs = params.rnaseq_sets_dirs ?
        Channel.fromPath(params.rnaseq_sets_dirs, checkIfExists: true) :
        Channel.empty()

    ch_rnaseq_sets_ids = params.rnaseq_sets_ids ?
        Channel.fromPath(params.rnaseq_sets_ids, checkIfExists: true) :
        Channel.empty()

    // ── Subworkflow ───────────────────────────────────────────────────────────
    BRAKER3_GENE_PREDICTION (
        ch_genomes,
        ch_rna_reads,
        ch_gtf,
        ch_proteins,
        ch_hintsfile,
        ch_rnaseq_sets_dirs,
        ch_rnaseq_sets_ids
    )
    ch_versions = ch_versions.mix(BRAKER3_GENE_PREDICTION.out.versions)

    emit:
    gtf         = BRAKER3_GENE_PREDICTION.out.gtf
    cds         = BRAKER3_GENE_PREDICTION.out.cds
    aa          = BRAKER3_GENE_PREDICTION.out.aa
    hintsfile   = BRAKER3_GENE_PREDICTION.out.hintsfile
    gff3        = BRAKER3_GENE_PREDICTION.out.gff3
    citations   = BRAKER3_GENE_PREDICTION.out.citations
    bam         = BRAKER3_GENE_PREDICTION.out.bam
    fastq       = BRAKER3_GENE_PREDICTION.out.fastq
    fastq_input = BRAKER3_GENE_PREDICTION.out.fastq_input
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
