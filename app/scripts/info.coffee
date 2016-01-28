React = require "react"
moment = require "moment"
require "moment-duration-format"

Segments = require "./segments"
Selection = require "./selection"
Cursor = require "./cursor"

AudioInfo = React.createClass
        componentWillMount: ->
            @_cb = => @forceUpdate()
            Segments.Segments.on 'add remove reset', @_cb

        componentWillUnmount: ->
            Segments.Segments.off null, @_cb
            @_cb = null

        render: ->
            times =
                if Segments.Segments.length > 0
                    [
                        moment(Segments.Segments.first().get("ts_actual")).format('MMM DD, h:mm:ssa'),
                        moment(Segments.Segments.last().get("end_ts_actual")).format('MMM DD, h:mm:ssa'),
                    ]
                else
                    ["--","--"]

            <div>
                <h4>Available Audio:</h4>
                {times[0]} to {times[1]}
            </div>

#----------

SelectionInfo = React.createClass
    componentWillMount: ->
        @_cb = => @forceUpdate()
        Selection.on "change", @_cb

    componentWillUnmount: ->
        Selection.off null, @_cb
        @_cb = null

    render: ->
        ints = if Selection.has("in") then moment(Selection.get('in')).format("MMM DD, h:mm:ss.SSSa") else "--"
        outts = if Selection.has("out") then moment(Selection.get('out')).format("MMM DD, h:mm:ss.SSSa") else "--"

        duration = if Selection.isValid()
            moment.duration(moment(Selection.get('out')).diff(Selection.get('in'))).format("h [hrs], m [min], s [sec], S [ms]")
        else
            "--"

        <div>
            <h4>Selection</h4>
            <span className="lead">In:</span> {ints}
            <br/><span className="lead">Out:</span> {outts}
            <br/><span className="lead">Duration:</span> {duration}
        </div>

#----------

CursorInfo = React.createClass
    componentWillMount: ->
        @_cb = => @forceUpdate()
        Cursor.on "change", @_cb

    componentWillUnmount: ->
        Cursor.off null, @_cb
        @_cb = null

    render: ->
        cursorts = if Cursor.has("ts") then moment(Cursor.get('ts')).format("MMM DD, h:mm:ss.SSSa") else "--"

        <div>
            <h4>Cursor</h4>
            {cursorts}
        </div>

#----------

module.exports = React.createClass
    # componentWillMount: ->
    #     Segments.Segments.on 'add remove reset', (=> @forceUpdate()), @
    #
    # componentWillUnmount: ->
    #     Segments.Segments.off null, null, @

    render: ->
        <div className="info row">
            <div className="col-md-6">
                <AudioInfo/>
                <CursorInfo/>
            </div>
            <div className="col-md-6">
                <SelectionInfo/>
            </div>
        </div>
