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
    render: ->
        ints = if @props.in then moment(@props.in).format("MMM DD, h:mm:ss.SSSa") else "--"
        outts = if @props.out then moment(@props.out).format("MMM DD, h:mm:ss.SSSa") else "--"

        duration = if @props.in && @props.out
            moment.duration(moment(@props.out).diff(@props.in)).format("h [hrs], m [min], s [sec], S [ms]")
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
    render: ->
        cursorts = if @props.ts then moment(@props.ts).format("MMM DD, h:mm:ss.SSSa") else "--"

        <div>
            <h4>Cursor</h4>
            {cursorts}
        </div>

#----------

module.exports = React.createClass
    render: ->
        <div className="info row">
            <div className="col-md-6">
                <AudioInfo/>
                <CursorInfo ts={@props.cursor}/>
            </div>
            <div className="col-md-6">
                <SelectionInfo in={@props.selectionIn} out={@props.selectionOut}/>
            </div>
        </div>
