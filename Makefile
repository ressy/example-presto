ERR = ERR346600
NUM_SPOTS = 25000
VPRIMERS = Greiff2014_VPrimers.fasta
CPRIMERS = Greiff2014_CPrimers.fasta

all: all_filt all_qc all_assembly

clean:
	rm -f *.log MPC_table.tab MPV_table.tab AP_table.tab FS_table.tab M1_*.tab M1*.fastq *.sorted

CHECKS = $(addsuffix .fastq.sorted,\
		$(addprefix M1_,assemble-pass quality-pass) \
		$(addprefix M1-,FWD_primers-pass REV_primers-pass)) \
	$(addsuffix .seqs.sorted,$(addprefix M1_,atleast-2 under-2 collapse-unique))

foo:
	echo $(CHECKS)
check: $(CHECKS)
	md5sum -c MANIFEST && rm -f *.sorted

# https://edwards.sdsu.edu/research/sorting-fastq-files-by-their-sequence-identifiers/
%.fastq.sorted : %.fastq
	paste - - - - < $^ | sort -k1,1 -t " " | tr "\t" "\n" > $@

%.seqs.sorted : %.fastq
	sed -n 2~4p < $^ | sort > $@

$(ERR)_1.fastq $(ERR)_2.fastq:
	fastq-dump --split-files -X $(NUM_SPOTS) $(ERR)
$(ERR)_2.fastq: $(ERR)_1.fastq

### Paired-end Assembly

all_assembly: AP_table.tab

# "During assembly we have defined read 2 (V-region) as the head of the sequence
# (-1) and read 1 as the tail of the sequence (-2). The --coord argument
# defines the format of the sequence header so that AssemblePairs can properly
# identify mate-pairs; in this case, we use --coord sra as our headers are in
# the SRA/ENA format."
M1_assemble-pass.fastq: $(ERR)_1.fastq $(ERR)_2.fastq
	AssemblePairs.py align -1 $(word 2,$^) -2 $(word 1,$^) \
	--coord sra --rc tail --outname M1 --log AP.log
AP.log: M1_assemble-pass.fastq

# Table of the AssemblePairs log
AP_table.tab: AP.log
	ParseLog.py -l $^ -f ID LENGTH OVERLAP ERROR PVALUE

### Quality Control

all_qc: MPC_table.tab MPV_table.tab FS_table.tab

# "In this example, reads with mean Phred quality scores less than 20 (-q 20)
# are removed"
M1_quality-pass.fastq: M1_assemble-pass.fastq
	FilterSeq.py quality -s $^ -q 20 --outname M1 --log FS.log
FS.log: M1_quality-pass.fastq

# Table of the FilterSeq log
FS_table.tab: FS.log
	ParseLog.py -l $^ -f ID QUALITY

# "The score subcommand of MaskPrimers is used to identify and remove the
# V-segment and C-region PCR primers for both reads"
# "The V-segment primer has been masked (replaced by Ns) using the --mode mask
# argument to preserve the V(D)J length, while the C-region primer has been
# removed from the sequence using the --mode cut argument."
M1-FWD_primers-pass.fastq: M1_quality-pass.fastq
	MaskPrimers.py score -s $^ -p $(VPRIMERS) \
	    --start 4 --mode mask --pf VPRIMER --outname M1-FWD --log MPV.log
MPV.log: M1-FWD_primers-pass.fastq

M1-REV_primers-pass.fastq: M1-FWD_primers-pass.fastq
	MaskPrimers.py score -s $^ -p $(CPRIMERS) \
	    --start 4 --mode cut --revpr --pf CPRIMER --outname M1-REV --log MPC.log
MPC.log: M1-REV_primers-pass.fastq

# MPV_table.tab	Table of the V-segment MaskPrimers log
MPV_table.tab: MPV.log MPC.log
	ParseLog.py -l $^ -f ID PRIMER ERROR
# MPC_table.tab	Table of the C-region MaskPrimers log
MPC_table.tab: MPV_table.tab

### Deduplication and Filtering

all_filt: M1_atleast-2_headers.tab

# Total unique sequences
# "First, the set of unique sequences is identified using the CollapseSeq tool,
# allowing for up to 20 interior N-valued positions (-n 20 and --inner), and
# requiring that all reads considered duplicates share the same C-region primer
# annotation (--uf CPRIMER). Additionally, the V-segment primer annotations of
# the set of duplicate reads are propagated into the annotation of each
# retained unique sequence (--cf VPRIMER and --act set)"
M1_collapse-unique.fastq: M1-REV_primers-pass.fastq
	CollapseSeq.py -s $^ -n 20 --inner --uf CPRIMER \
	    --cf VPRIMER --act set --outname M1

# Unique sequences represented by at least 2 reads
# "Following duplicate removal, the data is subset to only those unique
# sequence with at least two representative reads by using the group subcommand
# of SplitSeq on the count field (-f DUPCOUNT) and specifying a numeric
# threshold (--num 2)"
M1_atleast-2.fastq: M1_collapse-unique.fastq
	SplitSeq.py group -s $^ -f DUPCOUNT --num 2 --outname M1

# Annotation table of the atleast-2 file
# "Finally, the annotations, including duplicate read count (DUPCOUNT), isotype
# (CPRIMER) and V-segment primer (VPRIMER), of the final repertoire are then
# extracted from the SplitSeq output into a tab-delimited file using the table
# subcommand of ParseHeaders"
M1_atleast-2_headers.tab: M1_atleast-2.fastq
	ParseHeaders.py table -s $^ -f ID DUPCOUNT CPRIMER VPRIMER
