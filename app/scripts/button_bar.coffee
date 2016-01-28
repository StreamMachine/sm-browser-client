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
        @_cb = => @forceUpdate()
        Selection.on "change", @_cb

    componentWillUnmount: ->
        Selection.off null, @_cb
        @_cb = null

    render: ->
        if Selection.isValid()
            <ValidDownloadButton/>
        else
            <InvalidDownloadButton/>

#----------

SetPointButton = React.createClass
    componentWillMount: ->
        @_cb = => @forceUpdate()

        Cursor.on "change", @_cb
        Selection.on "change", @_cb

    componentWillUnmount: ->
        Cursor.off null, @_cb
        Selection.off null, @_cb
        @_cb = null

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
        @_cb = => @forceUpdate()
        Selection.on "change", @_cb

    componentWillUnmount: ->
        Selection.off null, @_cb
        @_cb = null

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
