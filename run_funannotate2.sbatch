#!/bin/bash --login

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64GB #requirements may be high in case user downloads large images
#SBATCH --partition=work
#SBATCH --time=1-00:00:00
#SBATCH --account=pawsey1142
#SBATCH --mail-type=ALL
#SBATCH --export=NONE

module load nextflow/25.04.6
module load singularity/4.1.0-slurm

export PAWSEY_PROJECT=pawsey1142  # Replace with your actual project ID
export MYSCRATCH=/scratch/pawsey1142/kgagalova/
export MYSOFTWARE=/software/scratch/pawsey1142/kgagalova/

#export FUNANNOTATE_DB=/scratch/y95/kgagalova/HGT/analysis-july/annotations/funannotate-pure/funannotate_db
export GENEMARK_PATH=/scratch/pawsey1142/kgagalova/shota-annotation/genemark_path/gmes_linux_64_4


nextflow run ./main.nf -profile pawsey_setonix,singularity -resume \
  --genomes '/scratch/pawsey1142/kgagalova/shota-annotation/resources/*.fa' \
  --transcripts '/scratch/pawsey1142/kgagalova/shota-annotation/resources/transcripts/M3_IP_IV_cat_transcript_nr_clustered_uniname.fa'


#  --database_dir '/scratch/pawsey1142/kgagalova/norin-cadenza/pathogen-genome/genome-anno-braker/mp-annotate_pangenomes/funannotate_db/'
#--database_dir '/scratch/pawsey1142/kgagalova/norin-cadenza/pathogen-genome/genome-anno/mp-annotate_pangenomes/funannotate_db_new/'
#--genemark_dir /scratch/y95/kgagalova/HGT/analysis-july/src/gmes_linux_64 \
#--transcripts /scratch/y95/kgagalova/HGT/analysis-july/annotations/transcriptome/Pnodorum_mRNA2.fasta \
