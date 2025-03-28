#----------------------------------------------------------------------
# svx_coverage trackBrowser track (i.e., a browserTrack)
#----------------------------------------------------------------------

# constructor for the S3 class
new_svx_coverageTrack <- function(trackId, click = FALSE, expand = NULL) {
    list( 
        click = click,
        hover = FALSE,
        brush = FALSE,
        items = TRUE,
        expand = expand,
        NULL
    )
}

# build method for the S3 class; REQUIRED
build.svx_coverageTrack <- function(track, reference, coord, layout, loadFn, 
                                    highlightsFn = NULL, highlightsStyle = "backgroundShading"){
    req(coord, coord$chromosome)

    # get operating parameters
    Plot_Type       <- getTrackSetting(track, "Coverage", "Plot_Type", "Read Depth")  
    Median_Ploidy   <- getTrackSetting(track, "Coverage", "Median_Ploidy", 2)
    plotBinSize     <- as.integer(getTrackSetting(track, "X_Axis", "Bin_Size", ""))
    if(!isTruthy(plotBinSize)) {
        maxBins <- getTrackSetting(track, "X_Axis", "Max_Bins", 250)
        plotBinSize <- floor(coord$width / maxBins)
    } else {
        maxBins <- floor(coord$width / plotBinSize)
    }

    # parse our binned coverage data source
    nSamples <- length(track$settings$items())
    selectedSources <- getSourcesFromTrackSamples(track$settings$items())
    dataFn <- function(track, reference, coord, sampleName, sample){
        I <- sapply(names(selectedSources), function(x) sampleName %in% selectedSources[[x]]$Sample_ID)
        sourceId <- names(selectedSources)[I] 
        x <- svx_filterCoverageByRange(sourceId, sampleName, coord, maxBins, loadFn) %>%
        svx_setCoverageValue(reference, coord, Plot_Type, Median_Ploidy) %>%
        aggregateTabixBins(track, coord, plotBinSize) %>%
        svx_maskLowQualityBins()
    }
    # cnvHighlightsFn <- function(track, reference, coord, sampleName, sample){
    #     I <- sapply(names(selectedSources), function(x) sampleName %in% selectedSources[[x]]$Sample_ID)
    #     x <- svx_getHmmCnvs(names(selectedSources)[I])
    #     if(!isTruthy(x)) return(NULL)
    #     x$value[[sampleName]][
    #         chrom == coord$chromosome &
    #         start <= coord$end & 
    #         coord$start <= end &
    #         !is.na(edgeType),
    #         .(
    #             x1 = start,
    #             x2 = end,
    #             color = ifelse(edgeType == svx_edgeTypes$DUPLICATION, rgb(1,0.2,0.2,0.075), rgb(0.2,0.2,1,0.075))
    #         )
    #     ]
    # }

    # build the binned_XY_track
    isDifference <- nSamples > 1 && getTrackSetting(track, "Data", "Aggregate", "none") == "difference"
    build.binned_XY_track(
        track, reference, coord, layout, 
        dataFn, 
        stranded = FALSE, 
        allowNeg = isDifference, 
        ylab = if(isDifference) paste(Plot_Type, "Change") else Plot_Type,
        center = TRUE, binSize = plotBinSize,
        highlightsFn = highlightsFn, highlightsStyle = highlightsStyle
        # ,
        # highlightsFn = cnvHighlightsFn
    )
}
