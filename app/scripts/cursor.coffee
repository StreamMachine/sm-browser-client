Backbone = require "backbone"
Dispatcher = require "./dispatcher"

CursorModel = class extends Backbone.Model
    initialize: ->
        @dispatchToken = Dispatcher.register (payload) =>
            switch payload.actionType
                when 'cursor-set'
                    console.log "Setting cursor to #{payload.ts}"
                    @set 'ts', payload.ts
                when 'cursor-clear'
                    @set 'ts', null

Cursor = new CursorModel

module.exports = Cursor
