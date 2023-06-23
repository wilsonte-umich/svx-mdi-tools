#----------------------------------------------------------------------
# server components for the keepReject appStep module
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# BEGIN MODULE SERVER
#----------------------------------------------------------------------
keepRejectServer <- function(id, options, bookmark, locks) { 
    moduleServer(id, function(input, output, session) {    
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# initialize module
#----------------------------------------------------------------------
module <- 'keepReject'
appStepDir <- getAppStepDir(module)
options <- setDefaultOptions(options, stepModuleInfo[[module]])
settings <- activateMdiHeaderLinks( # uncomment as needed
    session,
    # url = getDocumentationUrl("path/to/docs/README", domain = "xxx"), # for documentation
    # dir = appStepDir, # for terminal emulator
    envir = environment(), # for R console
    baseDirs = appStepDir, # for code viewer/editor
    # settings = id, # for step-level settings
    # immediate = TRUE # plus any other arguments passed to settingsServer()
)

#----------------------------------------------------------------------
# establish module outcomes
#----------------------------------------------------------------------
defaultThreshold <- list(
    minBaseQual = 25,
    minMapQ = 55
)
thresholds <- reactiveValues()
setThresholds <- function(d){
    ampliconKey <- getAmpliconKeys(selectedAmplicon())
    thresholds[[ampliconKey]] <- d
}

#----------------------------------------------------------------------
# get the samples and amplicons to plot
#----------------------------------------------------------------------
sampleSet <- sampleSetServer("sampleSet", id)
samples <- samplesReactive(sampleSet)
amplicons <- ampliconsReactive(samples)

#----------------------------------------------------------------------
# construct the amplicon table and cascading reactives
#----------------------------------------------------------------------
ampliconsTable <- ampliconsTableServer(id, input, amplicons, selection = "single")
selectedAmplicon <- selectedAmpliconsReactive(amplicons, ampliconsTable)
moleculeTypes <- moleculeTypesReactive(samples, selectedAmplicon)

#----------------------------------------------------------------------
# construct the path class table and composite paired quality plot
#----------------------------------------------------------------------
pathClasses <- pathClassesReactive(moleculeTypes)
pathClassesTable <- pathClassesTableServer(id, input, pathClasses, selection = "single")
pathClassMoleculeTypes <- pathClassMoleculeTypesReactive(moleculeTypes, pathClasses, pathClassesTable)
pairedQualityPlot <- pairedQualityPlotServer(pathClassMoleculeTypes)
observeEvent(pairedQualityPlot$click(), {
    d <- pairedQualityPlot$click()$coord
    setThresholds(list(minBaseQual = d$x, minMapQ = d$y))
})

#----------------------------------------------------------------------
# construct the molecule-level metadata and plot
#----------------------------------------------------------------------
keepRejectMoleculeTypes <- keepRejectMoleculeTypesReactive(pathClassMoleculeTypes, input)
moleculeTypeStepper <- listStepperButtonsServer("moleculeTypeStepper", keepRejectMoleculeTypes)
moleculeMetadata <- moleculeMetadataReactive(selectedAmplicon, moleculeTypeStepper)
output$moleculeMetadata <- moleculeMetadataUI(moleculeMetadata)
output$moleculeQcPlot <- renderPlot({ moleculeQcPlot(moleculeMetadata) }) 

#----------------------------------------------------------------------
# define bookmarking actions
#----------------------------------------------------------------------
observe({
    bm <- getModuleBookmark(id, module, bookmark, locks)
    req(bm)
    # settings$replace(bm$settings)
    updateSelectInput(session, "sampleSet-sampleSet", selected = bm$input[['sampleSet-sampleSet']])
    if(!is.null(bm$outcomes)) {
        thresholds <<- listToReactiveValues(bm$outcomes$thresholds)
    }
})

#----------------------------------------------------------------------
# set return values as reactives that will be assigned to app$data[[stepName]]
#----------------------------------------------------------------------
list(
    input = input,
    # settings = settings$all_,
    outcomes = reactive({ list(
        thresholds = reactiveValuesToList(thresholds)
    ) }),
    thresholds = function(amplicons = NULL){
        if(is.null(amplicons)) amplicons <- selectedAmplicon()
        ampliconKeys <- getAmpliconKeys(amplicons)
        x <- lapply(ampliconKeys, function(ampliconKey){
            if(is.null(thresholds[[ampliconKey]])) defaultThreshold else thresholds[[ampliconKey]]
        })  
        names(x) <- ampliconKeys
        x
    },
    # isReady = reactive({ getStepReadiness(options$source, ...) }),
    NULL
)

#----------------------------------------------------------------------
# END MODULE SERVER
#----------------------------------------------------------------------
})}
#----------------------------------------------------------------------