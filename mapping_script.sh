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

###################################
# Part 1. Get Sample Information  #
###################################
METADATA=$4
line_num=$((SLURM_ARRAY_TASK_ID + 1))

# Robust parsing to handle quotes/commas and find ALL SRA IDs for this fly
read -r sampleId srr_list <<< $(python3 -c "
import csv
with open('$METADATA', 'r') as f:
    reader = csv.reader(f)
    rows = list(reader)
    row = rows[$line_num-1]
    print(f'{row[0]} {row[1].replace(\",\", \" \")}')
")

numFlies=1
FASTQ_DIR=$2
OUT_DIR=$3
SIF_IMAGE=$1

###################################
# Part 2. Handle File Merging     #
###################################
srr_array=($srr_list)

if [ ${#srr_array[@]} -gt 1 ]; then
    echo "Multiple SRAs detected for ${sampleId}. Merging files..."
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

###################################
# Part 3. Run the Container       #
###################################
mkdir -p ${OUT_DIR}

# If your reads are Paired End use this version
apptainer run \
  --containall \
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

###################################
# Part 4. Cleanup                 #
###################################
if [ ${#srr_array[@]} -gt 1 ]; then
    rm "$R1_PATH" "$R2_PATH"
fi
