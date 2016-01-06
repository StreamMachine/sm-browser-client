#= require segments
#= require audio_manager

window.SM_Waveform = class
    constructor: (@_t,@_uriBase) ->
        @height = 300
        @preview_height = 50
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

        # -- Scales -- #

        @_x = d3.time.scale()
        @_y = d3.scale.linear()

        @_x.domain([@focus_segments.first().get("ts"),@focus_segments.last().get("end_ts")]).rangeRound([0,@width])
        @_y.domain([-128,128]).rangeRound([-(@height / 2),@height / 2])

        @_px = d3.time.scale()
        @_py = d3.scale.linear()

        @_px.domain([@segments.first().get("ts"),@segments.last().get("end_ts")]).range([0,@width])
        @_py.domain([-128,128]).rangeRound([-(@preview_height / 2),@preview_height / 2])

        # -- axis labels -- #

        @_xAxis = d3.svg.axis().scale(@_x).orient("bottom")
        @_pxAxis = d3.svg.axis().scale(@_px).orient("bottom")

        # -- Preview Graph with Brushing -- #

        @_previewg = d3.select(@_preview[0]).append("svg").style(width:"100%",height:"#{@preview_height+20}px")

        @_pwave = @segments.previewWave().resample(@width)

        @_brush = d3.svg.brush().x(@_px).extent(@_x.domain())
            .on "brush", =>
                if @_brush.empty()
                    # no brush selected, so focus all segments
                    @_x.domain @_px.domain()
                    @focus_segments.reset @segments.models
                else
                    @_x.domain @_brush.extent()
                    @focus_segments.reset @segments.selectDates @_x.domain()...

                @_zoom.x(@_x)
                @_updateFocusWaveform()
                @_drawCursor() if @_cursor

        area = d3.svg.area()
            .x( (d,i) -> i )
            .y0( (d,i) -> tthis._py(tthis._pwave.min[i]) )
            .y1( (d,i) -> tthis._py(d) )

        @_previewg.append("path")
            .attr("transform",-> "translate(0,#{tthis.preview_height/2})")
            .attr("d",area(@_pwave.max))

        @_previewg.append("g")
            .attr("class","x brush")
            .call(@_brush)
            .selectAll("rect")
            .attr("y",-6)
            .attr("height",@preview_height + 7)

        @_previewg.append("g")
            .attr("class","x axis")
            .attr("transform","translate(0,#{@preview_height})")
            .call(@_pxAxis)

        # -- Focus Graph -- #

        @_main = d3.select(@_zoom[0]).append("svg").style(width:"100%",height:"#{@height+20}px")

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

            if @_x(@_px.domain()[0]) > 0
                tx -= @_x(@_px.domain()[0])
            else if @_x(@_px.domain()[1]) < @_x.range()[1]
                tx -= @_x(@_px.domain()[1]) - @_x.range()[1]

            @_zoom.translate([tx,t[1]])

            # -- trigger updates -- #

            @_brush.extent @_x.domain()
            @_previewg.selectAll(".brush").call(@_brush)
            @focus_segments.reset @segments.selectDates @_x.domain()...
            @_updateFocusWaveform()
            @_drawCursor() if @_cursor

        @_main.call(@_zoom)

        true

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
            .on("click", (d,i) -> tthis._click(d,d3.event,this))
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

        console.log "playhead ts is #{ts}"
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
