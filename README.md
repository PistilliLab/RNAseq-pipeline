![GitHub release (with filter)](https://img.shields.io/github/v/release/PistilliLab/RNAseq-pipeline)
![Static Badge](https://img.shields.io/badge/maintained%3F-yes-Green)
![GitHub issues](https://img.shields.io/github/issues/PistilliLab/RNAseq-pipeline)
![GitHub](https://img.shields.io/github/license/PistilliLab/RNAseq-pipeline)

# RNAseq-pipeline
Pipeline for processing bulk RNA-seq data from raw .fastq files to read counts.

The pipeline is contained within a single shell script and processes short read paired-end .fastq files from bulk RNA-sequencing and outputs raw read counts (un-normalized).

# Usage
Currently the script is just executed using:

~~~
bash RNAseq-pipeline.sh -f /path/to/fastqs
~~~

```-f``` - designates the file path for the fastq files to be processed. This is also used as the main working directory and all output files will exist here.
