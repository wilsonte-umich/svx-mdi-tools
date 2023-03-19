use strict;
use warnings;

# initialize a numeric indexing scheme for fixed-width genome bins

# working variables
use vars qw($error $GENOME_FASTA $EXTRACT_PREFIX $WINDOW_SIZE 
            %chromIndex %revChromIndex);

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
    RNAME_INDEX => 13  # added by us    
};

# functions for converting between chromosome coordinates and window indexes
# encode in signed 32-bit integer as [strand = signed empty byte][chromIndex = 1 byte][windowIndex = 2 bytes]
# thus, runs of windows are numerically sequential, different chroms are obviously different, DNA strand is intuitively represented
sub coordinateToWindowIndex {
    int(($_[0] - 1) / $WINDOW_SIZE); # bases 1-100 => windowIndex 0 for windowSize==100
}
sub windowIndexToCoordinate {
    $_[0] * $WINDOW_SIZE + 1; # windowIndex 0 => base 1 (first base in window)
}
sub getUnsignedWindow {
    my ($chromIndex, $coordinate, $add) = @_;
    ($chromIndex << 16) + coordinateToWindowIndex($coordinate + $add);
}
sub getSignedWindow {
    my ($chromIndex, $coordinate, $strand, $add) = @_;
    getUnsignedWindow($chromIndex, $coordinate, $add) * ($strand eq "+" ? 1 : -1);
}
sub parseSignedWindow {
    my ($window) = @_;
    my $strand = $window > 0 ? "+" : "-";
    $window = abs($window);
    my $chromIndex = $window >> 16;
    {
        chromIndex  => $chromIndex,
        chrom       => $chromIndex ? $revChromIndex{$chromIndex} : "?",
        coordinate  => $window & (2**16 - 1),
        strand      => $strand
    }
}

# functions for creating a window coverage map 
# it's possible for short segments to disappear in the map if fully contained in a single window
my @windowCoverage;
sub initializeWindowCoverage {
    open my $inH, "<", "$GENOME_FASTA.fai" or die "$error: file not found: $GENOME_FASTA.fai\n";
    while(my $line = <$inH>){
        chomp $line;
        my ($chrom, $size) = split("\t", $line);
        $windowCoverage[$chromIndex{$chrom}] = [(0) x (coordinateToWindowIndex($size) + 2)];
    }
    close $inH; 
}
sub incrementWindowCoverage { # place up/down marks in windows
    my ($aln) = @_;
    $windowCoverage[$$aln[RNAME_INDEX]][coordinateToWindowIndex($$aln[RSTART] + 1)] +=  1; # up in the aln's first window
    $windowCoverage[$$aln[RNAME_INDEX]][coordinateToWindowIndex($$aln[REND]) + 1]   += -1; # down in the window AFTER this aln
}
sub printWindowCoverage {
    my ($childN) = @_;
    my $file = "$EXTRACT_PREFIX.windowCoverage.$childN.txt.gz";
    open my $outH, "|-", "gzip -c > $file" or die "$error: could not open: $file\n";
    foreach my $chromIndex (1..$#windowCoverage){
        my $chrom = $revChromIndex{$chromIndex};
        my $coverage = 0;
        foreach my $windowIndex (0..($#{$windowCoverage[$chromIndex]} - 1)){
            $coverage += $windowCoverage[$chromIndex][$windowIndex];
            print $outH join("\t", $chrom, windowIndexToCoordinate($windowIndex), $coverage), "\n";
        } 
    }
    close $outH;
}

1;
