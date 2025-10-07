2025-10-06 v1.5.0

- Removed .sam file to .bam file conversion section, now pipes hisat2 output directly to samtools sort
    - Reduced disk space requirements for all data by 143% (325.1 GB down to 54.0 GB on same dataset)
    - Reduced script runtime on same data set by 31% (130.5 min down to 95.9 min)
- Removed pre-run environment changes section as it is no longer necessary
- Added help flag that prints description of all flags
- Limit number of threads passed to featureCounts to 64
