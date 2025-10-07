![GitHub release (with filter)](https://img.shields.io/github/v/release/PistilliLab/RNAseq-pipeline)
![Static Badge](https://img.shields.io/badge/maintained%3F-yes-Green)
![GitHub issues](https://img.shields.io/github/issues/PistilliLab/RNAseq-pipeline)
![GitHub](https://img.shields.io/github/license/PistilliLab/RNAseq-pipeline)

# RNAseq-pipeline
Pipeline for processing bulk RNA-seq data from raw .fastq files to read counts.

The pipeline is contained within a single shell script and processes short read paired-end .fastq files from bulk RNA-sequencing and outputs raw read counts (un-normalized).

It is written to be ran on Linux, and is tested on Ubuntu so it should work on debian based systems at least.

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

```-f /path/to/fastqs``` Designates the file path for the fastq files to be processed. This is also used as the main working directory and all output files will exist here.

```-t <int>``` Number of threads to use. Must be integer value. If no input specified, then by default 80% of threads on the system will be used.

```-5 <int>``` Number of bases to trim from the 5' end of sequences.

```-3 <int>``` Number of bases to trim from the 3' end of sequences.

```-i <str>``` Specific reference genome index to use. Path to index files and .gtf must be defined in the script currently.

```-q``` Run script in QC only mode. This runs fastqc and multiqc and then exits. Useful for deciding -5 and -3 flag trim settings.

```-h``` Prints usage information.
