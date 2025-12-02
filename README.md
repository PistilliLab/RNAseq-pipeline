![GitHub release (with filter)](https://img.shields.io/github/v/release/PistilliLab/RNAseq-pipeline)
![Static Badge](https://img.shields.io/badge/maintained%3F-yes-Green)
![GitHub issues](https://img.shields.io/github/issues/PistilliLab/RNAseq-pipeline)
![GitHub](https://img.shields.io/github/license/PistilliLab/RNAseq-pipeline)

# RNAseq-pipeline
Pipeline for processing bulk RNA-seq data from raw .fastq files to read counts.

The pipeline is contained within a single shell script and processes short read paired-end .fastq files from bulk RNA-sequencing and outputs raw read counts (un-normalized).

It is written for use on Linux, and is tested on Ubuntu so it should work on debian based systems at least.

# Necessary software
The script assumes you are using a debian based linux distro, but it can be adapted for use on other versions (Fedora, Arch). The following programs must be installed otherwise the script will fail to run and exit with an error.

**fastqc**
~~~
sudo apt install fastqc
~~~

**multiqc**
~~~
sudo apt install multiqc
~~~

**hisat2**
~~~
sudo apt install hisat2
~~~

**samtools**
~~~
sudo apt install samtools
~~~

**featureCounts** (function of subread)
~~~
sudo apt install subread
~~~

**md5sum** (it may come with your install)
~~~
sudo apt install md5sum
~~~

# Usage
The available flags are defined below.

Example command:
~~~
bash RNAseq-pipeline_version.sh -f /path/to/fastqs -t 32 -5 30 -3 70 -i GRCm39
~~~

```-f /path/to/fastqs [required]``` Designates the file path for the fastq files to be processed. This is also used as the main working directory and all output files will exist here.

```-i <str> [required]``` Specific reference genome index to use. Path to index files and .gtf must be manually defined in the script.

```-t <int> [optional]``` Number of threads to use. Must be integer value. If no input specified, then by default 80% of threads on the system will be used.

```-5 <int> [optional]``` Number of bases to trim from the 5' end of sequences.

```-3 <int> [optional]``` Number of bases to trim from the 3' end of sequences.

```-q [optional]``` Run script in QC only mode. This runs fastqc and multiqc and then exits. Useful for deciding -5 and -3 flag trim settings.

```-h``` Prints usage information.

### Additional configuration section
This section includes additional settings that can be manually modified if necessary. Typically, they will not need to be altered.

#### sequencing platform
By default it is defined as "ILLUMINA". If another platform was used, it can be entered here for posterity.

#### strandedness
HISAT2 offers 3 options for strandedness when aligning reads.
~~~
R or RF for RF/fr-firststrand stranded (dUTP)
F or FR for FR/fr-secondstrand stranded (Ligation)
No inclusion of the flag for unstranded
~~~

Most relatively recent sequencing data will be dUTP (firststranded), abbreviated as "RF".

# Bulding reference genome index with hisat2
If there is no available index available or you just want to build it yourself, the following commands will let you build an index using hisat2. **Note: your machine must have at least 160 GB of memory available.**

Run each command in sequence.
~~~
hisat2_extract_splice_sites.py nameofgtffile.gtf > genome.ss
~~~

~~~
hisat2_extract_exons.py nameofgtffile.gtf > genome.exon
~~~

~~~
hisat2-build -p <num of threads> --exon genome.exon --ss genome.ss Reference_genome_primary_assembly.fa Output_name_of_index
~~~

