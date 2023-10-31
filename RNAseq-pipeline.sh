#! /bin/bash

# Get current date and time
current_date=$(date +%Y-%m-%d_%H-%M-%S)

# Get current user
username=$(whoami)

# Get aboslute path of current directory
current_dir=$(pwd)

############### Arguments ###############
# USAGE:
# -f /path/to/fastq/files
# -t <int>

while getopts f:m:t: flag
do
    case "${flag}" in
        f) fastq=${OPTARG};;
        t) threads=${OPTARG};;
    esac
done

#####################################################################
######################## USER DEFINED VALUES ########################
#####################################################################

# Make sure to enter the path to the location of the fastq files you want to process
# This script should take care of everything else after that
fastq_dir="$fastq"

# Number of threads to use
# If threads is not set or is empty, set it to 80% of system's threads
if [ -z "$threads" ]; then
    total_threads=$(nproc)
    threads=$((total_threads * 80 / 100))  # bash only performs integer arithmetic
fi

threads="$threads"

# Annotation files
GRCm39_annot="/home/${username}/Bioinformatics/Indexes/GRCm39/Mus_musculus.GRCm39.109.gtf"
T2T_annot="/home/${username}/Bioinformatics/Indexes/T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.gtf"

##### Settings for HISAT2 #####
# Name of sequencing platform
platform="ILLUMINA"

# Path to HISAT2 index for reference genome minus the trailing .X.ht2
GRCm39_index="/home/${username}/Bioinformatics/Indexes/GRCm39/Mus_musculus.GRCm39.dna.primary_assembly"
T2T_index="/home/${username}/Bioinformatics/Indexes/T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic"

# Path to hisat2 log file
alignments_dir="${fastq_dir}/alignments"
hisat2_log="${fastq_dir}/alignments_${current_date}.log"

# Strand setting for HISAT2
# There are three options for this setting
# R or RF for RF/fr-firststrand stranded (dUTP)
# F or FR for FR/fr-secondstrand stranded (Ligation)
# No inclusion of the flag for unstranded
rna_strandness="RF"

##### SAM to BAM #####
# Divides the number of threads to use by 2
jobs_to_run=$((threads/2))

# Path to featureCounts log file
featureCounts_log="${fastq_dir}/featureCounts_${current_date}.log"

#####################################################################
#####################################################################
#####################################################################

############### Pre-run environment changes ###############

# Reload .bashrc file. TODO: not sure why this is necessary, need to fix.
source ~/.bashrc

# Activate conda env.0/GCF
# Doing it this way instead of "conda activate bioinformatics" prevents conda init err
# This step may not be necessary
source /home/${username}/anaconda3/bin/activate base

############### Pre-run checks ###############

# Confirm necessary programs are installed and available
command -v fastqc >/dev/null 2>&1 || { echo >&2 "Script requires fastqc but it's not installed. Aborting."; exit 1; }
command -v multiqc >/dev/null 2>&1 || { echo >&2 "Script requires multiqc but it's not installed. Aborting."; exit 1; }
command -v hisat2 >/dev/null 2>&1 || { echo >&2 "Script requires hisat2 but it's not installed. Aborting."; exit 1; }
command -v samtools >/dev/null 2>&1 || { echo >&2 "Script requires samtools but it's not installed. Aborting."; exit 1; }
command -v parallel >/dev/null 2>&1 || { echo >&2 "Script requires parallel but it's not installed. Aborting."; exit 1; }
command -v featureCounts >/dev/null 2>&1 || { echo >&2 "Script requires featureCounts but it's not installed. Aborting."; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo >&2 "Script requires md5sum but it's not installed. Aborting."; exit 1; }

############### Verify md5 hashes ###############

# Change to fastq directory
cd "${fastq_dir}"

# Define log file path
md5_log_file="md5_verification_${current_date}.log"

# Flag to track if any mismatches are detected
mismatch_detected=0

# Check if md5.txt exists
if [[ -f md5.txt ]]; then
    # Process each fastq file
    for fastq in *.fastq.gz; do
        # Compute MD5 hash for the current fastq file
        computed_md5=$(md5sum "$fastq" | awk '{print $1}')

        # Extract expected MD5 hash from md5.txt
        expected_md5=$(grep "$fastq" md5.txt | awk '{print $1}')

        # Compare the two MD5 hashes and write results to log file
        if [[ "$computed_md5" == "$expected_md5" ]]; then
            printf "$fastq: MD5 match. Expected: $expected_md5, Computed: $computed_md5\n"
            echo "$fastq: MD5 match. Expected: $expected_md5 Computed: $computed_md5" >> "$md5_log_file"
        else
            printf "$fastq: MD5 mismatch! Expected: $expected_md5, Computed: $computed_md5\n"
            echo "$fastq: MD5 mismatch! Expected: $expected_md5, Computed: $computed_md5" >> "$md5_log_file"
            mismatch_detected=1
        fi
    done

    # If any mismatches were detected, exit the script
    if [[ $mismatch_detected -eq 1 ]]; then
        echo "File integrity verification failed, MD5 mismatches detected. View log for details. \nExiting script." >> "$log_file"
        exit 1
    fi

else
    echo "md5.txt not found! Expected in fastq directory. Can not verify file integrity." >> "$md5_log_file"

    # Prompt user whether to continue
    echo "Do you want to continue without verifying fastq file integrity? (yes/no)"
    read user_input

    # Check the user's response
    case "$user_input" in
        [Yy]|[Yy][Ee][Ss])
            echo "Continuing without verification..."
            ;;
        [Nn]|[Nn][Oo])
            echo "Exiting script."
            exit 1
            ;;
        *)
            echo "Invalid input. Exiting script."
            exit 1
            ;;
    esac
fi


############### Pre-alignment QC ###############

# Run fastqc on all FASTQ files in the directory
fastqc -t ${threads} *.fastq.gz

# Run multiqc in same directory as the fastqc reportsT2T_ind
multiqc .

# Rename the multiqc report
rename multiqc_report pre-alignment_multiqc_report_${current_date} ${fastq_dir}/multiqc_report.html

# Make new directory for the fastqc outputs and move
mkdir fastqc -p && mv *_fastqc* fastqc

############### HISAT2 alignment ###############

# Make alignments folder and cd
mkdir -p alignments && cd alignments

# Loop through all the paired read files in the directoryT2T_ind
for read1_file in ${fastq_dir}/*_R1.fastq.gz; do
  # Extract the file name without the path and file extension
  file_name=$(basename ${read1_file} _R1.fastq.gz)

  # Determine the corresponding read2 file
  read2_file=${fastq_dir}/${file_name}_R2.fastq.gz

  # Define the output file name
  output_file=${fastq_dir}/alignments/${file_name}

  # Print filename to log file
  echo "$file_name alignment results:" >> "${hisat2_log}"

  # Run HISAT2 on the read1 and read2 files and output to the output file
  cmd="hisat2 -p ${threads} -x ${GRCm39_index} --rna-strandness ${rna_strandness} --dta -1 ${read1_file} -2 ${read2_file} -S ${output_file}.sam >> ${hisat2_log} 2>&1"

  # Run command
  printf "Running command: ${cmd}\n"
  eval $cmd
done

############### SAM to BAM conversion ###############

# Function to run samtools
sam_to_bam() {
    sam_file=$1

    # Extract the file name without the path and file extension
    file_name=$(basename "${sam_file}" .sam)


    # Run samtools sort on sam files
    samtools sort -@ 2 -o "${file_name}".bam "${file_name}".sam

}

# Export the function so GNU parallel can use it
export -f sam_to_bam

# Use GNU parallel to run the function on each .sam file in parallel
find "${alignments_dir}" -name "*.sam" | parallel -j ${jobs_to_run} sam_to_bam

############### featureCounts ###############

# https://rnnh.github.io/bioinfo-notebook/docs/featureCounts.html
# -p = specifies that fragments will be counted instead of reads. For paired-end reads only.
# -O = assigns reads to all their overlapping meta-features
featureCounts -T ${threads} -p -O -a ${GRCm39_annot} -o "featureCounts_${current_date}.tsv" *.bam >> ${featureCounts_log} 2>&1
