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
    componentWillMount: ->
        Selection.on "change", =>
            console.log "force button update after selection change"
            @forceUpdate()

    componentWillUnmount: ->
        Selection.off null, null, @

    render: ->
        if Selection.isValid()
            <ValidDownloadButton/>
        else
            <InvalidDownloadButton/>

#----------

SetPointButton = React.createClass
    componentWillMount: ->
        Cursor.on "change", =>
            @forceUpdate()

        Selection.on "change", =>
            @forceUpdate()

    componentWillUnmount: ->
        Cursor.off null, null, @
        Selection.off null, null, @

    render: ->
        classes = "btn btn-default"

        onClick = =>
            Dispatcher.dispatch actionType:"selection-set-#{@props.point}", ts:Cursor.get('ts')

        if !Cursor.get('ts') || !Selection.validCursorFor(@props.point,Cursor.get('ts'))
            classes += " disabled"

        <button className={classes} onClick={onClick}>Set {@props.point}</button>

#----------

ClearSelectionButton = React.createClass
    componentWillMount: ->
        Selection.on "change", =>
            @forceUpdate()

    componentWillUnmount: ->
        Selection.off null, null, @

    render: ->
        onClick = => Dispatcher.dispatch actionType:"selection-clear"

        classes = "btn btn-default"

        if !Selection.get("in") && !Selection.get("out")
            classes += " disabled"

        <button className={classes} onClick={onClick}>Clear Selection</button>

#----------

module.exports = React.createClass
    componentWillMount: ->

    componentWillUnmount: ->

    render: ->
        <div>
            <DownloadButton/>
            <SetPointButton point="in"/>
            <SetPointButton point="out"/>
            <ClearSelectionButton/>
        </div>
