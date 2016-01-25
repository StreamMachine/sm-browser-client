React = require "react"

Segments = require "./segments"
Selection = require "./selection"

module.exports = React.createClass
    componentWillMount: ->
        Segments.Segments.on 'add remove reset', (=> @forceUpdate()), @

    componentWillUnmount: ->
        Segments.Segments.off null, null, @

    render: ->
        <div className="info">
            <p>
                <b>Available Audio:</b>
                {Segments.Segments.first()?.get("ts_actual").toISOString() || "--"}
                to
                {Segments.Segments.last()?.get("end_ts_actual").toISOString() || "--"}
            </p>
        </div>
