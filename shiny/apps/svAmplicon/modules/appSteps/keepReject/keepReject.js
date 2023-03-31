// add a moving vertical reference line
Shiny.addCustomMessageHandler("cellPlotsWrapperInit", function(opt){

    // parse interactive targets 
    const wrapperId = "#" + opt.prefix + opt.divId;
    const mdiVertical = wrapperId + " .cellStackVertical";
    const cellWindowsPlot = wrapperId + " .cellWindowsPlot";

    // convert document to widget coordinates
    const relCoord = function(event, element){return {
        x: event.pageX - $(element).offset().left,
        y: event.pageY - $(element).offset().top,
    }}

    // activate plot clicks
    let clickIsActivated = false;

    // handle all requested interactions, listed here if rough order of occurrence
    $(wrapperId).off("mouseenter").on("mouseenter", function() {
        $(mdiVertical).show();
        if(!clickIsActivated){
            $(cellWindowsPlot).off("click").on("click", function(event){
                const data = {
                    coord: relCoord(event, this),
                    keys: {
                        ctrl:  event.ctrlKey,
                        alt:   event.altKey,
                        shift: event.shiftKey
                    },
                    data: $(this).data()
                };
                Shiny.setInputValue(opt.prefix + 'cellWindowsPlotClick', data, { priority: "event" });        
            })
            clickIsActivated = true;
        }
    });
    $(wrapperId).off("mousemove").on("mousemove", function(event) {
        const coord = relCoord(event, this);
        $(mdiVertical).css({left: coord.x - 2});
    });
    $(wrapperId).off("mouseleave").on("mouseleave", function() {
        $(mdiVertical).hide();
    });
});
Shiny.addCustomMessageHandler("cellPlotsWrapperUpdate", function(opt){
    let h = (1.35 * 96 + 2) * opt.cellsPerPage + 25;
    if(opt.short === true) h = h / 2 + 10;
    const wrapperId = "#" + opt.prefix + opt.divId;
    const mdiVertical = wrapperId + " .cellStackVertical";
    $(mdiVertical).css({height: h});
});
