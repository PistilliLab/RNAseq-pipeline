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
# -i "INDEX"
# -3 <int>
# -5 <int>
# -q

while getopts f:t:i:3:5:q flag
do
    case "${flag}" in
        f) fastq=${OPTARG};;
        t) threads=${OPTARG};;
        i) index=${OPTARG};;
        3) three_prime=${OPTARG};;
        5) five_prime=${OPTARG};;
        q) qc_mode=${OPTARG};;
    esac
done

# Set default values to 0 if three_prime and five_prime were not provided
three_prime=${three_prime:-0}
five_prime=${five_prime:-0}

# Assuming 'index' will be either 'GRCm39' or 'T2T', you can use it to select the corresponding index later in the script.

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

# Use 'selected_index' and 'selected_annot' variables instead of the hardcoded paths later in the script.


#####################################################################
######################## USER DEFINED VALUES ########################
#####################################################################

# Make sure to enter the path to the location of the fastq files you want to process
# This script should take care of everything else after that
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

threads="$threads"

##### Settings for HISAT2 #####
# Name of sequencing platform
platform="ILLUMINA"

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
#source ~/.bashrc

# Activate conda env.0/GCF
# Doing it this way instead of "conda activate bioinformatics" prevents conda init err
# This step may not be necessary
source activate Bioinformatics

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

    # Check the user's responseBy ensuring the variable is compared correctly and not accid
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

############### HISAT2 alignment ###############

# Make alignments folder and cd
mkdir -p alignments && cd alignments

# Loop through all the paired read files in the directoryT2T_ind
for read1_file in ${fastq_dir}/*_R1_001.fastq.gz; do
  # Extract the file name without the path and file extension
  file_name=$(basename ${read1_file} _R1_001.fastq.gz)

  # Determine the corresponding read2 file
  read2_file=${fastq_dir}/${file_name}_R2_001.fastq.gz

  # Define the output file name
  output_file=${fastq_dir}/alignments/${file_name}

  # Print filename to log file
  echo "$file_name alignment results:" >> "${hisat2_log}"

  # Run HISAT2 on the read1 and read2 files and output to the output file
  cmd="hisat2 -p ${threads} -5 ${five_prime} -3 ${three_prime} -x ${selected_index} --rna-strandness ${rna_strandness} --dta -1 ${read1_file} -2 ${read2_file} -S ${output_file}.sam >> ${hisat2_log} 2>&1"

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
featureCounts -T ${threads} -p -O -a ${selected_annot} -o "featureCounts_${current_date}.tsv" *.bam >> ${featureCounts_log} 2>&1

# Finish Logging
} 2>&1 | log_with_timestamp | tee -a "$LOGFILE"

