#!/bin/bash --login

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64GB #requirements may be high in case user downloads large images
#SBATCH --partition=work
#SBATCH --time=1-00:00:00
#SBATCH --account=y95
#SBATCH --mail-type=ALL
#SBATCH --export=NONE

module load nextflow/23.10.0
module load singularity/4.1.0-slurm

export PAWSEY_PROJECT=y95  # Replace with your actual project ID
export MYSCRATCH=/scratch/y95/kgagalova/
export MYSOFTWARE=/software/scratch/y95/kgagalova/

#export FUNANNOTATE_DB=/scratch/y95/kgagalova/HGT/analysis-july/annotations/funannotate-pure/funannotate_db
#export GENEMARK_PATH=/scratch/y95/kgagalova/HGT/analysis-july/src/gmes_linux_64

nextflow run main.nf \
    -profile setonix,singularity \
    --transcripts /scratch/y95/kgagalova/HGT/analysis-july/transcriptome_assembly/assemby_out/dedup/All.transcripts_dedupRenam.fa \
    --genomes '/scratch/y95/kgagalova/HGT/analysis-july/annotations/genomes_cleaned/renamed/*.fa' \
    --outdir results \
    -resume

#--genemark_dir /scratch/y95/kgagalova/HGT/analysis-july/src/gmes_linux_64 \
#--transcripts /scratch/y95/kgagalova/HGT/analysis-july/annotations/transcriptome/Pnodorum_mRNA2.fasta \
