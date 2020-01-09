# pRESTO Example

This follows along with the [pRESTO example] for antibody sequencing analysis
for non-UMI Illumina data, using 25,0000 2x250 nt reads of their data from
[ERR346600].  In their workflow the reverse read starts in the V region and
heads toward J, and vice versa for the forward read.  The rules in `Makefile`
do essentially the same thing as their example shell script in the
[example tarball].

    conda env update --file environment.yml && conda activate example-presto && make

[pRESTO example]: https://presto.readthedocs.io/en/stable/workflows/Greiff2014_Workflow.html
[ERR346600]: https://www.ncbi.nlm.nih.gov/sra/ERR346600
[example tarball]: http://clip.med.yale.edu/immcantation/examples/Greiff2014_Example.tar.gz
