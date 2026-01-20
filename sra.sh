!/usr/bin/env bash
#
#SBATCH -J download_sra
#SBATCH -c 6
#SBATCH -N 1
#SBATCH -t 12:00:00
#SBATCH --mem 20G
#SBATCH -o /scratch/cqh6wn/Isofemale/logs/sra.%A_%a.out
#SBATCH -e /scratch/cqh6wn/Isofemale/logs/sra.%A_%a.err
#SBATCH -p standard
#SBATCH --account=berglandlab



module purge
module load gcc/11.4.0
module load sratoolkit/3.1.1


OUT_DIR="/scratch/cqh6wn/Isofemale/fastq_files"
mkdir -p ${OUT_DIR}


srr=$( sed -n "${SLURM_ARRAY_TASK_ID}p" /scratch/cqh6wn/Isofemale/sra_list.txt )

echo "Working on SRA: ${srr}"


if [ -f "${OUT_DIR}/${srr}_1.fastq.gz" ]; then
    echo "${srr} already downloaded. Skipping."
    exit 0
fi



fasterq-dump ${srr} \
    --split-files \
    --outdir ${OUT_DIR} \
    --threads ${SLURM_CPUS_PER_TASK} \
    --temp /scratch/cqh6wn/temp


# DEST pipeline requires .gz files
gzip "${OUT_DIR}/${srr}_1.fastq"
gzip "${OUT_DIR}/${srr}_2.fastq"

echo "Download and compression of ${srr} complete."
