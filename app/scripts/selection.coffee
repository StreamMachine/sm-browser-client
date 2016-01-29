Backbone = require "backbone"
Dispatcher = require "./dispatcher"

SelectionModel = class extends Backbone.Model
    initialize: ->
        @dispatchToken = Dispatcher.register (payload) =>
            switch payload.actionType
                when "selection-set-in"
                    if !@attributes.out || payload.ts < @attributes.out
                        @set "in", payload.ts
                when "selection-set-out"
                    if !@attributes.in || payload.ts > @attributes.in
                        @set "out", payload.ts
                when "selection-clear"
                    @set in:null, out:null

    defaults: ->
        in: null
        out: null

    download_link: ->
        return "" if !@isValid()

        "#{@attributes.uriBase}/export?start=#{@attributes.in.toISOString()}&end=#{@attributes.out.toISOString()}"

    validate: (attrs) ->
        # require in_point and out_point to be dates
        if !attrs.in || !_.isDate(attrs.in)
            return "in is required and must be a date"

        if !attrs.out || !_.isDate(attrs.out)
            return "out is required and must be a date"

        if attrs.in >= attrs.out
            return "in is required to be earlier than out"

    validCursorFor: (point,ts) ->
        if @attributes[point] == ts
            return false
        else if point == "in" && @attributes.out && ts >= @attributes.out
            return false
        else if point == "out" && @attributes.in && ts <= @attributes.in
            return false
        else
            return true

Selection = new SelectionModel

module.exports = Selection
