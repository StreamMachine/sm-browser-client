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

SMBrowserComponent = React.createClass
    componentWillMount: ->
        @_scb = =>
            @setState
                selectionIn:    Selection.get('in')
                selectionOut:   Selection.get('out')
                selectionValid: Selection.isValid()

        Selection.on "change", @_scb

        @_ccb = =>
            @setState cursor:Cursor.get('ts')

        Cursor.on "change", @_ccb

    componentWillUnmount: ->
        Selection.off null, @_scb
        Cursor.off null, @_ccb

    getInitialState: ->
        selectionIn:    Selection.get('in')
        selectionOut:   Selection.get('out')
        selectionValid: Selection.isValid()
        cursor:         Cursor.get('ts')

    render: ->
        <div className="sm-browser">
            <ButtonBar selectionValid={@state.selectionValid} selectionIn={@state.selectionIn} selectionOut={@state.selectionOut} cursor={@state.cursor}/>
            <Info selectionIn={@state.selectionIn} selectionOut={@state.selectionOut} cursor={@state.cursor}/>
        </div>

SMBrowser = React.createFactory(SMBrowserComponent)

#----------

class Main
    DefaultOptions:
        target: "#wave"
        uri_base: null
        initial_duration: moment.duration(10,"m")
        wave_height: 300
        preview_height: 50

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

        Cursor.on "change", =>
            console.log "Cursor is now ", Cursor.get('ts')

        $.getJSON "#{@opts.uri_base}/preview", (data) =>
            console.log "Wave segments loaded."
            Segments.Segments.reset(data)

        Segments.Segments.on "reset", =>
            # set initial focus segments
            end_date = Segments.Segments.last().get("end_ts")
            begin_date = moment(end_date).subtract(@opts.initial_duration).toDate()
            Segments.Focus.reset Segments.Segments.selectDates(begin_date,end_date)

        @$t = $(@opts.target)

        @$wave = $ "<div/>"
        @$ui = $ "<div/>"
        @$t.append @$wave
        @$t.append @$ui

        # -- Render UI -- #

        @sm_browser = SMBrowser()
        ReactDom.render @sm_browser, @$ui[0]

        # -- Render Waveforms -- #

        @wave = new SM_Waveform @$wave, @opts

module.exports = Main
