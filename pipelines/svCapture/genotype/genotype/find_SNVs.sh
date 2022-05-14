# action:
#     search for SNVs near SV junctions in comparision to source sample alleles
# expects:
#     genotype/build_haplotypes.sh
# input:
#     $GENOTYPE_PREFIX.unphased_haplotypes.gz
# outputs:
#     $GENOTYPE_PREFIX.snvs_indels.rds

# log file feedback
echo "searching for SNVs and indels near called SV junctions"
Rscript $ACTION_DIR/genotype/find_SNVs.R
checkPipe

echo "done"
