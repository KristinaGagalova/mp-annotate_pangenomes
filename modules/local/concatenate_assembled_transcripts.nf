process CONCAT_DEDUPLICATE_TRANSCRIPTS {

    tag "concat_dedup_transcripts_by_id"
    label 'process_low'
    
    input:
    path transcript_files

    output:
    path "concatenated_deduplicated_transcripts.fa", emit: transcripts
    path "deduplication_stats.txt", emit: stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # Count sequences before deduplication
    BEFORE_COUNT=\$(grep -c "^>" ${transcript_files} || echo "0")
    echo "Sequences before deduplication: \$BEFORE_COUNT" >> deduplication_stats.txt
    
    # Remove duplicate sequences based on sequence
    seqkit rmdup \\
        --by-seq \
        --ignore-case \
        ${args} \
        ${transcript_files} \
    | awk '
    /^>/{
        split(\$0,a," ")
        id=a[1]
        count[id]++
        if(count[id]>1){
            a[1]=id"_"count[id]
        }
        \$0=a[1]
        for(i=2;i in a;i++) \$0=\$0" "a[i]
    }
    {print}
    ' \
    > concatenated_deduplicated_transcripts.fa
    
    # Count sequences after deduplication
    AFTER_COUNT=\$(grep -c "^>" concatenated_deduplicated_transcripts.fa || echo "0")
    echo "Sequences after deduplication: \$AFTER_COUNT" >> deduplication_stats.txt
    
    # Calculate removed sequences
    REMOVED_COUNT=\$((BEFORE_COUNT - AFTER_COUNT))
    echo "Duplicate sequences removed: \$REMOVED_COUNT" >> deduplication_stats.txt
    
    # Clean up intermediate file
    rm concatenated_transcripts.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    """
    touch concatenated_deduplicated_transcripts.fa
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: 
    END_VERSIONS
    """
}
