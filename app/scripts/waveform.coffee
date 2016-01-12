#= require segments
#= require audio_manager

window.SM_Waveform = class
    constructor: (@_t,@_uriBase) ->
        @height = 300
        @preview_height = 50
        @locator_height = 20
        @initial_duration = moment.duration(10,"m")

        @_segWidth = null

        @target = $ @_t
        @width  = @target.width()

        # -- create our elements -- #

        @_zoom = @target.append("<div>")
        @_preview = @target.append("<div>")

        # -- set up audio -- #

        @_audioctx = new (window.AudioContext || window.webkitAudioContext)()

        # -- set up segments collection -- #

        @segments = new SM_Segments.Segments audio:@_audioctx, baseURI:@_uriBase
        @segments.once "reset", =>
            @_initFocusSegments()
            @_initCharts()
            @_updateFocusWaveform()

        # this is a segment collection that we'll use just to represent the
        # extent of segments that should be shown in the focused view
        @focus_segments = new SM_Segments.Segments

        $.getJSON "#{@_uriBase}/preview", (data) =>
            @segments.reset(data)

        # -- watch for play/pause -- #

        @_playing = null

        playheadFunc = (ts) =>
            @_drawPlayhead(ts)

        $(document).on "keyup", (e) =>
            console.log "keycode is ", e.keyCode
            if e.keyCode == 32
                # spacebar

                if @_playing
                    console.log "Stopping"
                    @_playing.stop()
                    @_playing.off()
                    @_playing = null

                    @_drawPlayhead(null)

                else
                    console.log "Playing", @_cursor
                    @_playing = new SM_AudioManager @_audioctx, @segments, @_cursor
                    @_playing.play()

                    @_playing.on "playhead", playheadFunc

    #----------

    _initFocusSegments: ->
        # using the end date of the segments and the initial_duration, select
        # the appropriate segments into our focus segments collection

        end_date = @segments.last().get("end_ts")
        begin_date = moment(end_date).subtract(@initial_duration).toDate()

        @focus_segments.reset @segments.selectDates(begin_date,end_date)

    #----------

    _click: (seg,evt,select,segWidth) ->
        d3m = d3.mouse(@_main.node())

        console.log "evt/d3m is ", evt, d3m

        @_setCursorPosition @_x.invert(d3m[0])

    #----------

    _setCursorPosition: (ts) ->
        @_cursor = ts
        console.log "Set cursor to #{ts}"
        @_drawCursor()

    #----------

    _initCharts: ->
        tthis = @

        @_previewIsBrushing = false

        # -- Scales -- #

        @_x = d3.time.scale()
        @_y = d3.scale.linear()

        @_x.domain([@focus_segments.first().get("ts"),@focus_segments.last().get("end_ts")]).rangeRound([0,@width])
        @_y.domain([-128,128]).rangeRound([-(@height / 2),@height / 2])

        @_px = d3.time.scale()
        @_pxIdx = d3.scale.linear()
        @_py = d3.scale.linear()

        @_pwave = @segments.previewWave()

        @_px.domain([@segments.first().get("ts"),@segments.last().get("end_ts")]).range([0,@width])
        @_pxIdx.domain([0,@_pwave.adapter.data.length]).rangeRound([0,@width])
        @_py.domain([-128,128]).rangeRound([-(@preview_height / 2),@preview_height / 2])

        @_fullx = d3.time.scale().domain([@segments.first().get("ts"),@segments.last().get("end_ts")]).range([0,@width])

        #@_updatePreviewDomain()

        # -- axis labels -- #

        @_xAxis = d3.svg.axis().scale(@_x).orient("bottom")
        @_pxAxis = d3.svg.axis().scale(@_px).orient("bottom")

        # -- Preview Graph with Brushing -- #

        @_previewg = d3.select(@_preview[0]).append("svg").attr("class","preview").style(width:"100%",height:"#{@preview_height+20}px")

        @_pwave = @segments.previewWave() #.resample(@width)

        @_brush = d3.svg.brush().x(@_px).extent(@_x.domain())
            .on "brushstart", =>
                @_previewIsBrushing = true
            .on "brushend", =>
                @_previewIsBrushing = false
                console.log "brush extent is ", @_brush.extent(), @_px.domain()
            .on "brush", =>
                if @_brush.empty()
                    # no brush selected, so focus all segments in our preview
                    @_x.domain @_px.domain()
                    @focus_segments.reset @segments.selectDates @_x.domain()...
                else
                    @_x.domain @_brush.extent()
                    @focus_segments.reset @segments.selectDates @_x.domain()...

                @_drawPreview()

                @_zoom.x(@_x)
                @_updateFocusWaveform()
                @_drawCursor() if @_cursor

        pmin = @_pwave.min
        pmax = @_pwave.max
        @_previewArea = d3.svg.area()
            .x( (d) -> tthis._pxIdx(d) )
            .y0( (d) -> tthis._py(pmin[d]) )
            .y1( (d) -> tthis._py(pmax[d]) )

        @_previewPath = @_previewg.append("path")
            .attr("transform","translate(0,#{@preview_height/2})")

        @_previewg.append("g")
            .attr("class","x brush")
            .call(@_brush)
            .selectAll("rect")
            .attr("y",-6)
            .attr("height",@preview_height + 7)

        @_pxAxis_s = @_previewg.append("g")
            .attr("class","x axis")
            .attr("transform","translate(0,#{@preview_height})")
            .call(@_pxAxis)

        @_drawPreview()

        # @_pzoom = d3.behavior.zoom().scaleExtent([1,1])
        # @_pzoom.x(@_px)
        # @_previewg.call(@_pzoom)

        # -- Focus Graph -- #

        @_main = d3.select(@_zoom[0]).append("svg").style(width:"100%",height:"#{@height+20}px")

        @_main.on("click", (d,i) -> tthis._click(d,d3.event,this))


        @_xAxis_s = @_main.append("g")
            .attr("class","x axis")
            .attr("transform","translate(0,#{@height})")
            .call(@_xAxis)

        @_zoom = d3.behavior.zoom().scaleExtent([1,1])
        @_zoom.x(@_x)
        @_zoom.on "zoom", =>
            # -- validate target -- #

            t = @_zoom.translate()
            tx = t[0]

            if @_x(@_fullx.domain()[0]) > 0
                tx -= @_x(@_fullx.domain()[0])
            else if @_x(@_fullx.domain()[1]) < @_x.range()[1]
                tx -= @_x(@_fullx.domain()[1]) - @_x.range()[1]

            @_zoom.translate([tx,t[1]])

            # -- trigger updates -- #

            @_drawPreview()
            @_brush.extent @_x.domain()

            @_previewg.selectAll(".brush").call(@_brush)
            @focus_segments.reset @segments.selectDates @_x.domain()...
            @_updateFocusWaveform()
            @_drawCursor() if @_cursor

        @_main.call(@_zoom)

        true

    #----------

    # resample the given subsection of the preview wave to fit into the
    # domain that should be shown, then update the preview line with that
    # data
    _drawPreview: ->
        # should we make any changes to our domain?
        @_updatePreviewDomains()

        # only draw the visible portion of the preview
        @_previewPath.attr("d",@_previewArea([@_pxIdx.invert(0)..@_pxIdx.invert(@width)]))

        # update our axis
        @_pxAxis_s.call(@_pxAxis)

        @_brush.extent @_x.domain()
        @_previewg.selectAll(".brush").call(@_brush)

    #----------

    # preview domain should zoom to where our focus area is 50% of preview
    # width, stopping when we reach the max resolution of our preview
    _updatePreviewDomains: ->
        # if we're brushing, don't do any zooming, just allow scrolling
        if @_previewIsBrushing
            # if brush extent is near the edge of our domain, scroll the
            # domain to accomodate
            bext = @_brush.extent()
            pd = @_px.domain()

            adjustment = 0

            if @_px(bext[0]) / @width <= 0.02
                # attempt to scroll left
                adjustment = Number(bext[0]) - Number(@_px.invert(@width*0.02))

            else if @_px(bext[1]) / @width >= 0.98
                # attempt to scroll right
                adjustment = Number(bext[1]) - Number(@_px.invert(@width*0.98))

            ld = new Date( Number(pd[0]) + adjustment)
            rd = new Date( Number(pd[1]) + adjustment)
        else
            # -- zoom domains -- #

            targetWidth = @width / 1.5

            # ask @_x for the domain values that are 50% out in either direction
            ld = @_x.invert(-1*targetWidth)
            rd = @_x.invert(@width+targetWidth)

            # is the resolution too high?
            msecs = Number(rd) - Number(ld)

            pdata = @segments.previewWave().adapter.data

            mintime = pdata.samples_per_pixel / pdata.sample_rate * @width

            if msecs / 1000 < mintime
                # zoomed in too far... zoom out to our minimum time period
                add_secs = mintime - (msecs / 1000)
                #console.log "Adding #{add_secs} to preview"

                ld = new Date( Number(ld) - add_secs*1000 / 2 )
                rd = new Date( Number(rd) + add_secs*1000 / 2 )

        # clamp against values we actually have
        fulld = @_fullx.domain()

        if ld < fulld[0]
            correction = Number(fulld[0]) - Number(ld)
            ld = fulld[0]
            rd = new Date( Number(rd) + correction )

        if rd > fulld[1]
            correction = Number(rd) - Number(fulld[1])
            rd = fulld[1]
            ld = new Date( Math.max(( Number(ld) - correction ),Number(fulld[0])))

        ld = fulld[0] if ld < fulld[0]
        rd = fulld[1] if rd > fulld[1]

        # now convert these values into pixels in the preview waveform

        sec_start = Math.floor((Number(ld) - Number(fulld[0])) / 1000)
        sec_end = Math.ceil((Number(rd) - Number(fulld[0])) / 1000)

        offset_start = @_pwave.at_time(sec_start)
        offset_end = @_pwave.at_time(sec_end)

        @_px.domain([ld,rd])
        @_pxIdx.domain([offset_start,offset_end])
        #@_brush.x(@_px)

    #----------

    _updateFocusWaveform: ->
        tthis = @

        # target sample rate is the duration of our x scale * sample rate / width
        d = @_x.domain()
        dur = (Number(d[1]) - Number(d[0])) / 1000
        targetRate = Math.ceil( dur * 44100 / @width )

        #console.log "updateFocusWaveform called. Target rate is #{targetRate} for #{@focus_segments.length} segments"

        segs = @_main.selectAll(".segment").data( @focus_segments.models, (s) -> s.id )

        segs.enter().append("g")
            .attr("class","segment")
            .attr("segment",(d) -> d.id)

        segs.exit().remove()

        segs
            .attr("transform", (d,i) ->
                "translate(#{ tthis._x( d.get("ts_actual") ) },#{ tthis.height / 2 })"
            ).each (d,i) ->
                s = d3.select(this)
                # is a re-render necessary?
                if Number(s.attr("targetRate")) != targetRate
                    #console.log "Need to redraw segment #{d.id} for #{targetRate} samples/pixel"
                    s.attr("targetRate",targetRate)
                    s.selectAll("*").remove()

                    pixels = (tthis._x( d.get("end_ts_actual") ) - tthis._x( d.get("ts_actual") ) || 1) + 1
                    #console.log "Segment will be #{pixels}px"
                    s.attr("pixels",pixels)

                    d.downsampled_wave pixels, (err,wave) =>
                        if pixels == 2
                            # draw a vertical line
                            s.append("line").attr("x1",0).attr("x2",0).attr("y1",wave.max[0]).attr("y2",wave.min[0])

                        else

                            wavearea = d3.svg.area()
                                .x( (d,i) -> i )
                                .y0( (d,i) -> tthis._y(wave.min[i]) )
                                .y1( (d,i) -> tthis._y(d) )

                            s.append("path").attr("d",wavearea( wave.max ))

        @_xAxis_s.call(@_xAxis)

    #----------

    _drawCursor: ->
        tthis = @
        c = @_main.selectAll(".cursor").data([@_cursor])

        c.enter().append("g")
            .attr("class","cursor")
            .append("path")

        c.select("path")
            .attr("d", (d,i) -> "M#{tthis._x(d)},0v0,#{tthis.height}Z" )

    #----------

    _drawPlayhead: (ts) ->
        tthis = @

        if ts
            c = @_main.selectAll(".playhead").data([ts])

            c.enter().append("g")
                .attr("class","playhead")
                .append("path")

            c.select("path")
                .attr("d", (ts) -> "M#{tthis._x(ts)},0v0,#{tthis.height}Z")
        else
            @_main.selectAll(".playhead").remove()

    #----------
