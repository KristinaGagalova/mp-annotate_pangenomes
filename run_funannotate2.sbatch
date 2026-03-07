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
#export GENEMARK_PATH=/scratch/y95/kgagalova/HGT/analysis-july/src/gmes_linux_64


nextflow run ./main.nf \
  --reads manifest.tsv \
  --genomes '/scratch/pawsey1142/kgagalova/norin-cadenza/pathogen-genome/repeat-anno/results/pn143_final/final/*.fasta'

#--genemark_dir /scratch/y95/kgagalova/HGT/analysis-july/src/gmes_linux_64 \
#--transcripts /scratch/y95/kgagalova/HGT/analysis-july/annotations/transcriptome/Pnodorum_mRNA2.fasta \
