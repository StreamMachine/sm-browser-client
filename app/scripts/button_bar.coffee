React = require "react"

Segments = require "./segments"
Selection = require "./selection"
Cursor = require "./cursor"

Dispatcher = require "./dispatcher"

#----------

ValidDownloadButton = React.createClass
    render: ->
        <a href={Selection.download_link()} className="btn btn-primary">Download Selection</a>

InvalidDownloadButton = React.createClass
    render: ->
        <button className="btn disabled">Download Selection</button>

DownloadButton = React.createClass
    render: ->
        if @props.valid
            <ValidDownloadButton/>
        else
            <InvalidDownloadButton/>

#----------

SetPointButton = React.createClass
    render: ->
        classes = "btn btn-default"

        onClick = =>
            Dispatcher.dispatch actionType:"selection-set-#{@props.point}", ts:@props.cursor

        if !@props.cursor || !Selection.validCursorFor(@props.point,@props.cursor)
            classes += " disabled"

        <button className={classes} onClick={onClick}>Set {@props.point}</button>

#----------

ClearSelectionButton = React.createClass
    render: ->
        onClick = => Dispatcher.dispatch actionType:"selection-clear"

        classes = "btn btn-default"

        if !@props.in && !@props.out
            classes += " disabled"

        <button className={classes} onClick={onClick}>Clear Selection</button>

#----------

module.exports = React.createClass
    render: ->
        <div>
            <DownloadButton valid={@props.selectionValid}/>
            <SetPointButton point="in" in={@props.selectionIn} out={@props.selectionOut} cursor={@props.cursor}/>
            <SetPointButton point="out" in={@props.selectionIn} out={@props.selectionOut} cursor={@props.cursor}/>
            <ClearSelectionButton in={@props.selectionIn} out={@props.selectionOut}/>
        </div>
