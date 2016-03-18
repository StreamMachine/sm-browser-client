React = require "react"
ReactDom = require "react-dom"

moment = require "moment"

ButtonBar   = require "./button_bar"
#Waveforms   = require "./waveforms"
Info        = require "./info"

Dispatcher  = require "./dispatcher"
Cursor      = require "./cursor"
Selection   = require "./selection"
Segments    = require "./segments"

SM_Waveform = require "./waveform"
AudioManager = require "./audio_manager"

class Main
    DefaultOptions:
        target: "#wave"
        uri_base: null
        initial_duration: moment.duration(10,"m")
        wave_height: 300
        preview_height: 50
        poll_interval: 10000

    constructor: (opts) ->
        @opts = _.defaults opts, @DefaultOptions

        if !@opts.uri_base
            throw "URI Base is a required argument."

        console.log "setting segment uri base to #{@opts.uri_base}"
        Segments.Segments.uriBase = @opts.uri_base
        Selection.set "uriBase", @opts.uri_base

        @_segments = Segments.Segments
        @_focus_segments = Segments.Focus
        @_cursor = Cursor
        @_dispatcher = Dispatcher

        @_shouldPoll = true
        @_segPollTimeout = null

        @$t = $(@opts.target)

        @$wave = $ "<div/>"
        @$ui = $ "<div/>"
        @$t.append @$wave
        @$t.append @$ui

        @audio = new AudioManager()

        # -- Manage Data -- #

        Cursor.on "change", =>
            console.log "Cursor is now ", Cursor.get('ts')
            @_render()

        Selection.on "change", => @_render()

        Segments.Segments.on 'add remove reset', => @_render()

        # Pull our stream audio info
        $.getJSON "#{@opts.uri_base}/info", (info) =>
            @audio.setInfo info

        @_pollForSegments()

        Segments.Segments.on "add remove", =>
            console.log "Segments added/removed"

        # set initial focus segments the first time we get segments
        Segments.Segments.once "reset", =>
            console.log "Segments got reset"
            end_date = Segments.Segments.last().get("end_ts")
            begin_date = moment(end_date).subtract(@opts.initial_duration).toDate()
            Segments.Focus.reset Segments.Segments.selectDates(begin_date,end_date)
            @_render()

        # -- Render Waveforms -- #

        @wave = new SM_Waveform @$wave, @audio, @opts

    #----------

    stop: ->
        @_shouldPoll = false
        clearTimeout @_segPollTimeout if @_segPollTimeout
        @_segPollTimeout = null

    #----------

    _pollForSegments: ->
        $.getJSON "#{@opts.uri_base}/preview", (data) =>
            Segments.Segments.loadPreview(data)

            if @_shouldPoll
                @_segPollTimeout = setTimeout =>
                    @_pollForSegments()
                , @opts.poll_interval

    #----------

    _render: ->
        sIn = Selection.get('in')
        sOut = Selection.get('out')
        sValid = Selection.isValid()
        cursor = Cursor.get('ts')
        segStart = Segments.Segments.first()?.get("ts_actual")
        segEnd = Segments.Segments.last()?.get("end_ts_actual")

        ReactDom.render(
            <div className="sm-browser">
                <ButtonBar selectionValid={sValid} selectionIn={sIn} selectionOut={sOut} cursor={cursor}/>
                <Info selectionIn={sIn} selectionOut={sOut} cursor={cursor} audioStart={segStart} audioEnd={segEnd}/>
            </div>
        , @$ui[0])

module.exports = Main
