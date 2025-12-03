#! /bin/bash

# Current script version
version=1.5.1

# Get current date and time
current_date=$(date +%Y-%m-%d_%H-%M-%S)

# Get current user
username=$(whoami)

# Get absolute path of current directory
current_dir=$(pwd)

############### Arguments ###############
# USAGE:
# -f /path/to/fastq/files
# -t <int>
# -i "INDEX"
# -3 <int>
# -5 <int>
# -q
# -h

# Set the default value for QC mode
qc_mode=false

# Text for help option
print_help() {
    cat << EOF
Usage: $(basename "$0") [options]

Options:
  -f  <path>   Path to directory containing FASTQ files (required)
  -t  <int>    Number of threads to use (default: 80% of available cores)
  -i  <string> Reference genome index to use [GRCm39 | T2T] (required)
  -3  <int>    Trim this many bases from the 3' end of reads (default: 0)
  -5  <int>    Trim this many bases from the 5' end of reads (default: 0)
  -q           Run QC mode only (perform FastQC + MultiQC, then exit)
  -h           Show this help message and exit

Example:
  $(basename "$0") -f /data/fastq -t 12 -i GRCm39 -3 5 -5 5

Description:
  This script performs a complete RNA-seq processing pipeline:
    • Verifies FASTQ file integrity via MD5 checks
    • Runs FastQC and MultiQC
    • Aligns reads with HISAT2
    • Converts alignments directly to BAM (no SAM files)
    • Counts features using featureCounts

EOF
}


# Arg parsing
while getopts f:t:i:3:5qh flag
do
    case "${flag}" in
        f) fastq=${OPTARG};;
        t) threads=${OPTARG};;
        i) index=${OPTARG};;
        3) three_prime=${OPTARG};;
        5) five_prime=${OPTARG};;
        q) qc_mode=true;;
        h) print_help; exit 0;;
    esac
done


# Verify required flags
if [[ -z "$fastq" || -z "$index" ]]; then
    echo "Error: Missing required arguments."
    print_help
    exit 1
fi


# Set default values to 0 if three_prime and five_prime were not provided
three_prime=${three_prime:-0}
five_prime=${five_prime:-0}

# Assuming 'index' will be either 'GRCm39' or 'T2T', you can use it to select the corresponding index later in the script.

TODO: Add function below this to check if the index files exist, otherwise return not found error.
# Set the path to the selected index based on the provided value
case "$index" in
    GRCm39)
        selected_index="/home/${username}/Bioinformatics/Indexes/GRCm39/Mus_musculus.GRCm39.dna.primary_assembly"
        selected_annot="/home/${username}/Bioinformatics/Indexes/GRCm39/Mus_musculus.GRCm39.109.gtf"
        ;;
    T2T)
        selected_index="/home/${username}/Bioinformatics/Indexes/T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic"
        selected_annot="/home/${username}/Bioinformatics/Indexes/T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.gtf"
        ;;
    *)
        echo "Invalid index option provided. Please specify either 'GRCm39' or 'T2T' with the -i flag."
        exit 1
        ;;
esac


#####################################################################
######################## USER DEFINED VALUES ########################
#####################################################################

# Do not manually set the values here, they are defined by flags.

fastq_dir="$fastq"

# Echo the original command and arguments with a timestamp
LOGFILE="${fastq}/${current_date}.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Command: $0 $@" | tee -a "$LOGFILE"

# Function to log each line with a timestamp
log_with_timestamp() {
    while IFS= read -r line; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $line"
    done
}

# Function to log script exit
log_exit() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Script exited with status $?" | tee -a "$LOGFILE"
}

# Trap exit and call log_exit function
trap log_exit EXIT

{

# Number of threads to use
# If threads is not set or is empty, set it to 80% of system's threads
if [ -z "$threads" ]; then
    total_threads=$(nproc)
    threads=$((total_threads * 80 / 100))  # bash only performs integer arithmetic
fi

# User defined max thread count
threads="$threads"

##### Settings for HISAT2 #####

# Path to hisat2 log file
alignments_dir="${fastq_dir}/alignments"
hisat2_log="${fastq_dir}/alignments_${current_date}.log"

# Path to featureCounts log file
featureCounts_log="${fastq_dir}/featureCounts_${current_date}.log"

#####################################################################
#####################################################################
#####################################################################

#####################################################################
##################### Additional configuration ######################
#####################################################################

# These settings can be manually modified if necessary, but typically do not need to be.

##### Settings for HISAT2 #####
# Name of sequencing platform
platform="ILLUMINA"

# Strand setting for HISAT2
# There are three options for this setting
# R or RF for RF/fr-firststrand stranded (dUTP)
# F or FR for FR/fr-secondstrand stranded (Ligation)
# No inclusion of the flag for unstranded
rna_strandness="RF"

#####################################################################
#####################################################################
#####################################################################

############### Pre-run checks ###############

prereq_software=("fastqc" "multiqc" "hisat2" "samtools" "featureCounts" "md5sum")

# Confirm necessary programs are installed and available
missing_soft=0

for software in "${prereq_software[@]}"; do
    if ! command -v "$software" >/dev/null 2>&1; then
        echo "Script requires $software but it's not installed."
        missing_soft=$((missing_soft+1))
    fi
done

# If necessary programs absent, attempt to install.
if [[ $missing_soft -gt 0 ]]; then
    echo "Missing software detected. Attempt to install necessary software to continue? (y/n)"
    read -r user_input

    case "$user_input" in
        [Yy]|[Yy][Ee][Ss])
            echo "Attempting to install missing software..."
            sudo apt update
            sudo apt install fastqc multiqc hisat2 samtools subread md5sum
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
else
    echo "All necessary software installed, continuing..."
fi

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

    # Check for valid user response
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

# Run multiqc in same directory as the fastqc reports
multiqc .

# Make new directory for the fastqc outputs and move
mkdir fastqc -p && mv *_fastqc* fastqc

# If -q flag is passed, stop the script
if [ "$qc_mode" = true ]; then
    echo "QC complete. Exiting script."
    exit 1
fi

############### HISAT2 alignment (streamed to BAM) ###############

mkdir -p "${alignments_dir}" && cd "${alignments_dir}"

for read1_file in ${fastq_dir}/*_R1_001.fastq.gz; do
  file_name=$(basename "${read1_file}" _R1_001.fastq.gz)
  read2_file="${fastq_dir}/${file_name}_R2_001.fastq.gz"
  output_bam="${alignments_dir}/${file_name}.bam"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting alignment for ${file_name}" | tee -a "${hisat2_log}"

  cmd="hisat2 -p ${threads} -5 ${five_prime} -3 ${three_prime} \
       -x ${selected_index} \
       --rna-strandness ${rna_strandness} --dta \
       -1 ${read1_file} -2 ${read2_file} 2>>${hisat2_log} | \
       samtools sort -@ ${threads} -o ${output_bam}"

  printf "Running command: ${cmd}\n"
  eval $cmd

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished alignment for ${file_name}" | tee -a "${hisat2_log}"
done

############### featureCounts ###############

# https://rnnh.github.io/bioinfo-notebook/docs/featureCounts.html
# -p = specifies that fragments will be counted instead of reads. For paired-end reads only.
# -O = assigns reads to all their overlapping meta-features

# Limit featureCounts to a maximum of 64 threads
if (( threads > 64 )); then
    echo "featureCounts supports a maximum of 64 threads. Reducing from ${threads} to 64." | tee -a "$featureCounts_log"
    threads=64
fi

featureCounts -T ${threads} -p -O -a ${selected_annot} -o "featureCounts_${current_date}.tsv" *.bam >> ${featureCounts_log} 2>&1

# Finish Logging
} 2>&1 | log_with_timestamp | tee -a "$LOGFILE"

