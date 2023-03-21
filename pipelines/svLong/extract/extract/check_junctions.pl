use strict;
use warnings;

# examine SV junctions for evidence of chimeric reads
# see:
#   https://github.com/nanoporetech/duplex-tools/blob/master/fillet.md
#   https://github.com/nanoporetech/duplex-tools/blob/master/duplex_tools/split_on_adapter.py
# occurs when a molecule has duplex reads, or when two molecules pass one after another
# when this occurs, the read structure is expected to be: 
#   >>====<<>>=====<<
# where >> and << are the adapter and its complement
# duplex_tools and porechop_abio can trim and split, but prefer to do it here, with alignment guidance
# svLong wants to collapse, not keep, redundant strands in duplex pairs
#
# can use porechop_abi, installed into the align conda environment to infer adapters
#   https://www.biorxiv.org/content/10.1101/2022.07.07.499093v1.full
#   https://github.com/bonsai-team/Porechop_ABI
# hints: must manually assemble a single fastq file with >=40,000 reads (so not ideal for automation)

# constants
use constant {
    QNAME => 0, # PAF fields
    QLEN => 1,
    QSTART => 2,
    QEND => 3,
    STRAND => 4,
    RNAME => 5,
    RLEN => 6,
    RSTART => 7,
    REND => 8,
    N_MATCHES => 9,
    N_BASES => 10,
    MAPQ => 11,
    PAF_TAGS => 12,
    RNAME_INDEX => 13,  # added by us  
    #-------------
    ALIGNMENT     => "A", # the single type for a contiguous aligned segment
    TRANSLOCATION => "T", # edge/junction types (might be several per source molecule)
    INVERSION     => "V",
    DUPLICATION   => "U",
    DELETION      => "D",
    UNKNOWN       => "?",
    INSERTION     => "I", 
    #-------------
    MATCH_OP      => "M",
    NULL_OP       => "X"
};

# working variables
use vars qw($INPUT_DIR $molId @nodes @types @mapQs @sizes @insSizes @outAlns);   
# open our $faH, "<", $ENV{GENOME_FASTA} or die "could not open: $ENV{GENOME_FASTA}\n";
# loadFaidx($ENV{GENOME_FASTA});

# ONT adapter information (also see notes below)
my $HEAD_ADAPTER = 'AATGTACTTCGTTCAGTTACGTATTGCT'; # TACTTCGTTCAGTTACGTATTGCT ~reproducible at QSTART, further 5' end increasingly variable
my $TAIL_ADAPTER = 'GCAATACGTAACTGAACGAAGT';
my $adapterTarget = $TAIL_ADAPTER.$HEAD_ADAPTER;

# check whether the molecule is consistent with a duplex foldback inversion
# if yes, keep first half only and mark molecules as duplex
# is most sensitive and acceptable to reject any inversion with reverse-complement overlap between its flanking alignments
#   ----->
#         | V
#   <-----
# strictly speaking we expect symmetry, but cannot count on complete alignment of both flanks
# per above, would expect adapters in the junction, but exploration says they are rarely there
sub checkForDuplex {
    my ($nEdges) = @_;
    $nEdges > 1 or return 1;
    for(my $i = 0; $i <= $#types; $i++){
        $types[$i] eq INVERSION or next;     
        if($outAlns[$i - 1][RSTART] <= $outAlns[$i + 1][REND] and
           $outAlns[$i + 1][RSTART] <= $outAlns[$i - 1][REND]){
            my $j = $i - 1;
            @types = @types[0..$j]; # no need to splice @nodes, they'll never print
            @mapQs = @mapQs[0..$j];
            @sizes = @sizes[0..$j];
            @insSizes = @insSizes[0..$j];
            return 2;
        }
    }
    return 1;
}

# check each junction for the potential that it is a chimera
# if yes, split the molecule into two
sub checkForChimericJunctions {
    my ($nEdges) = @_;
    # TODO as needed
    # if needed, restore require of get_indexed_reads.pl
    # my @read = getIndexedRead($molId); # to get the read bases
    # can already judge presence of clipped insertions from PAF parsing
}

# print a validated molecule to STDOUT
sub printMolecule {
    my ($nStrands) = @_;
    my $out = ""; # "----------------------------\n";  
    foreach my $i(0..$#types){
        $out .= join(
            "\t", 
            $molId,
            $nodes[$i], 
            $nodes[$i + 1], 
            $types[$i], 
            $mapQs[$i], 
            $sizes[$i], 
            $insSizes[$i],
            $nStrands
        )."\n";
    }
    print $out; 
}

1;

# Notes from examination clip sequences and SV junctions

# average start clip is 37 to 39 bases
# average end clip is 10 to 12 bases

# very first read bases are erratic and unreliable, likely due to pore still loading
# start adapter bases become more recognizable at the genome fragment junction
# end clip is short likely because the molecule disengages from enzyme and quickly exits the pore

# results from running porechop_abi
# Start
# Consensus_1_start_(50.0%)
#         TATT TACTTCGTTCAGTTACGTATTGCT 28 # ~matches duplex_tools HEAD_ADAPTER
# AGCAATACGTAACTGAACGAAGTAAATA = reverse complement
# Consensus_2_start_(50.0%)
# TGTTATGTCCTG TACTTCGTTCAGTTACGTATTGCT 35
# AGCAATACGTAACTGAACGAAGTACAGGACATAACA = reverse complement

# End
# Consensus_1_end_(100.0%)
# TAGATGATAATCATTATCACTTTACGGGTCCTTTCCGGTGAAAAAGAA 48 # mysterious where this comes from, can't match it to any clips, ADAPTER, etc.
# TTCTTTTTCACCGGAAAGGACCCGTAAAGTGATAATGATTATCATCTA reverse complement

# the standard ONT genomic adapter configuration is:
# ---               -
#    ---|=======|---
#    ---|=======|---
#   -               ---
# thus, the bases fused to start and end are reverse complements
#   ...TACTTCGTTCAGTTACGTATTGCT|=======|AGCAATACGT...
#                 ...TGCATAACGA|=======|TCGTTATGCA...

# code used during debugging, included useful CIGAR-driven alignment
    # # require that outermost alignments are matched, on opposite strands, within window resolution
    # my $i = 0;
    # my $j = $#outAlns;
    # my $refChrom1 = $outAlns[$i][RNAME];
    # my $refChrom2 = $outAlns[$j][RNAME];
    # $refChrom1 eq $refChrom2 or return 1;
    # abs($nodes[0] + $nodes[$#nodes]) == 0 or return 1; # ADJUST THRESHOLD LATER  

    # # collect reference coordinates in ref and query
    # my $isTop1   = $outAlns[$i][STRAND] eq "+" ? 1 : 0;
    # my $isTop2   = $outAlns[$j][STRAND] eq "+" ? 1 : 0;
    # my $qryPos11 = $outAlns[$i][QSTART];
    # my $qryPos12 = $outAlns[$i][QEND];
    # my $qryPos21 = $outAlns[$j][QSTART];        
    # my $qryPos22 = $outAlns[$j][QEND];     
    # my $refPos1L = $outAlns[$i][RSTART]; 
    # my $refPos1R = $outAlns[$i][REND];
    # my $refPos2L = $outAlns[$j][RSTART];
    # my $refPos2R = $outAlns[$j][REND];

    # # extract the relevant subsequences
    # my @read = getIndexedRead($molId);    
    # my $ref1 = getRefSeq($refChrom1, $refPos1L + 1, $refPos1R);
    # my $ref2 = getRefSeq($refChrom2, $refPos2L + 1, $refPos2R);
    # my $qry1 = substr($read[1], $qryPos11, $qryPos12 - $qryPos11);
    # my $qry2 = substr($read[1], $qryPos21, $qryPos22 - $qryPos21);
    # $isTop1 or rc(\$qry1);
    # $isTop2 or rc(\$qry2);
    
    # # parse the alignments
    # my @ref1 = split("", $ref1);
    # my @ref2 = split("", $ref2); 
    # my $qryOnRef1 = getQryOnRef($qry1, $outAlns[$i]); # need to update to pass CIGAR, not aln
    # my $qryOnRef2 = getQryOnRef($qry2, $outAlns[$j]);
    # my @match1 = map { $ref1[$_] eq $$qryOnRef1[$_] ? "|" : " " } 0..$#ref1;
    # my @match2 = map { $ref2[$_] eq $$qryOnRef2[$_] ? "|" : " " } 0..$#ref2;

    # # pad for co-display of both sides
    # my $padL = $refPos2L - $refPos1L;
    # if($padL >= 0){
    #     unshift @ref2,       ((" ") x $padL);
    #     unshift @$qryOnRef2, ((" ") x $padL); 
    #     unshift @match2,     ((" ") x $padL);
    # } else {
    #     unshift @ref1,       ((" ") x -$padL);
    #     unshift @$qryOnRef1, ((" ") x -$padL); 
    #     unshift @match1,     ((" ") x -$padL);
    # }
    # my $padR = $refPos2R - $refPos1R;
    # if($padR >= 0){
    #     push @ref1,       ((" ") x $padR);
    #     push @$qryOnRef1, ((" ") x $padR); 
    #     push @match1,     ((" ") x $padR);
    # } else {
    #     push @ref2,       ((" ") x -$padR);
    #     push @$qryOnRef2, ((" ") x -$padR); 
    #     push @match2,     ((" ") x -$padR);
    # }

    # printMolecule();
    # print join("\t", $qryPos11 + 1, $qryPos12, $qryPos21 + 1, $qryPos22), "\n";
    # print join("\t", $refPos1L + 1, $refPos1R, $refPos2L + 1, $refPos2R), "\n";  
    # my $lineLength = 100;
    # for(my $i = 0; $i <= $#ref1; $i += $lineLength){ 
    #     my $j = min($i + $lineLength - 1, $#ref1); 
    #     print join("", @$qryOnRef1[$i..$j]), "\n"; 
    #     print join("", @match1[$i..$j]), "\n"; 
    #     print join("", @ref1[$i..$j]), "\n";   
    #     print join("", @ref2[$i..$j]), "\n";   
    #     print join("", @match2[$i..$j]), "\n";   
    #     print join("", @$qryOnRef2[$i..$j]), "\n\n"; 
    # }
