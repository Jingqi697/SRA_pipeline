#!/usr/bin/env bash
#
#SBATCH -J dest_mapping
#SBATCH -c 11
#SBATCH -N 1
#SBATCH -t 72:00:00
#SBATCH --mem 90G
#SBATCH -o /scratch/cqh6wn/Isofemale/logs/map.%A_%a.out
#SBATCH -e /scratch/cqh6wn/Isofemale/logs/map.%A_%a.err
#SBATCH -p standard
#SBATCH --account=berglandlab

### modules
module purge
module load apptainer

### Sample information
METADATA=$4
line_num=$((SLURM_ARRAY_TASK_ID + 1)) ## Skip the header row

read -r sampleId srr_list <<< $(python3 -c " # Extract first column (sample name) and second column (SRAs)
import csv
with open('$METADATA', 'r') as f:
    reader = csv.reader(f)
    rows = list(reader)
    row = rows[$line_num-1]
    print(f'{row[0]} {row[1].replace(\",\", \" \")}') 
")

numFlies=1 ##  Isofemale lines
FASTQ_DIR=$2
OUT_DIR=$3
SIF_IMAGE=$1

### File merging
srr_array=($srr_list) 
if [ ${#srr_array[@]} -gt 1 ]; then # Merge if 1 sample cotains more than 1 srr file
    R1_PATH="${FASTQ_DIR}/${sampleId}_merged_1.fastq.gz"
    R2_PATH="${FASTQ_DIR}/${sampleId}_merged_2.fastq.gz"
    > "$R1_PATH"
    > "$R2_PATH"
    for srr in "${srr_array[@]}"; do
        cat "${FASTQ_DIR}/${srr}_1.fastq.gz" >> "$R1_PATH"
        cat "${FASTQ_DIR}/${srr}_2.fastq.gz" >> "$R2_PATH"
    done
else
    srr=${srr_array[0]}
    R1_PATH="${FASTQ_DIR}/${srr}_1.fastq.gz"
    R2_PATH="${FASTQ_DIR}/${srr}_2.fastq.gz"
fi


mkdir -p ${OUT_DIR}


export APPTAINERENV_TMPDIR=/scratch/cqh6wn/Isofemale/tmp # Handle space issue
mkdir -p $APPTAINERENV_TMPDIR

apptainer run \
  --bind /scratch,/project,/standard \
  ${SIF_IMAGE} \
  ${R1_PATH} \
  ${R2_PATH} \
  ${sampleId} \
  ${OUT_DIR} \
  --cores $SLURM_CPUS_PER_TASK \
  --max-cov 0.95 \
  --min-cov 4 \
  --base-quality-threshold 25 \
  --num-flies ${numFlies} \
  --do_poolsnp

### Clean up
if [ ${#srr_array[@]} -gt 1 ]; then
    rm "$R1_PATH" "$R2_PATH"
fi
