Backbone = require "backbone"
Dispatcher = require "./dispatcher"

SelectionModel = class extends Backbone.Model
    initialize: ->
        @dispatchToken = Dispatcher.register (payload) =>
            switch payload.actionType
                when "selection-set-in"
                    console.log "Setting selection in to #{ payload.ts }"
                    @set "in", payload.ts
                when "selection-set-out"
                    @set "out", payload.ts

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

Selection = new SelectionModel

module.exports = Selection
