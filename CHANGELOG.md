2025-12-02 v1.5.1
- Some code cleanup
- Restructured user defined values, split into a section that can be changed called additional configurations
- Following failed verification of necessary software prerequisites, script offers to try installing software
- Improved documentation

2025-10-06 v1.5.0

- Removed .sam file to .bam file conversion section, now pipes hisat2 output directly to samtools sort
    - Reduced disk space requirements for all data by 83% (325.1 GB down to 54.0 GB on same dataset)
    - Reduced script runtime on same data set by 27% (130.5 min down to 95.9 min)
- Removed pre-run environment changes section as it is no longer necessary
- Added help flag that prints description of all flags
- Limit number of threads passed to featureCounts to 64
