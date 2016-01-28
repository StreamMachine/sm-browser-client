Backbone = require "backbone"
bowser = require "bowser"

Segments = require "./segments"
Cursor = require "./cursor"
Dispatcher = require "./dispatcher"

SegmentPlayer = class
    constructor: (@ts) ->
        _.extend(@, Backbone.Events)

        @_playheadTick = null
        @_loadTick = null

        @_elapsed = 0

        @_audio = document.createElement("audio")
        @_source = new MediaSource()
        @_audio.src = window.URL.createObjectURL(@_source)

        @_waiting = []

        @_source.addEventListener "sourceopen", =>
            # FIXME: type needs to get loaded in to support mp3

            if bowser.safari
                @_sourceBuffer = @_source.addSourceBuffer('audio/mp4; codecs="mp4a.40.2"')
            else
                @_sourceBuffer = @_source.addSourceBuffer('audio/aac')

            @_sourceBuffer.addEventListener "updateend", =>
                @_ready = true
                @trigger "ready"
                @_fireAppend()

            @_fireAppend()

        # we want to always have three segments loaded... the current one
        # and two after it
        @_loaded = []

        seg = Segments.Segments.findByTimestamp(@ts)
        @_load(seg)

        console.log "AudioManager: cursor / ts_actual", @ts, seg.get("ts_actual")
        @_initialSeek = (Number(@ts) - Number(seg.get("ts_actual"))) / 1000
        console.log "Initial seek inside the segment should be #{@_initialSeek}"

        @_playing = null
        @_stopped = false

        @_ready = false

        true

    #----------

    _fireAppend: ->
        return false if !@_sourceBuffer || @_sourceBuffer.updating || @_waiting.length == 0

        buffer = @_waiting.shift()

        # slice to strip ID3 tag with timestamp
        @_sourceBuffer.appendBuffer(buffer.slice(73))

    #----------

    _append: (buf) ->
        @_waiting.push buf
        @_fireAppend()

    #----------

    once_ready: (cb) ->
        if @_ready
            cb()
        else
            @once "ready", cb

    #----------

    play: ->
        if @_playing
            return false

        @once_ready =>
            @_play()

    #----------

    pause: ->
        @_audio.pause()


    #----------

    stop: ->
        @_stopped = true
        @_audio.pause()

        clearInterval @_playheadTick if @_playheadTick
        @_playheadTick = null

        clearInterval @_loadTick if @_loadTick
        @_loadTick = null

        @trigger "stop"

    #----------

    _play: ->
        @_audio.currentTime = @_initialSeek

        @_audio.play()

        @_playheadTick = setInterval =>
            @trigger "playhead", new Date(Number(@ts) + @_audio.currentTime*1000 - @_initialSeek*1000)
        , 33

        @_loadTick = setInterval =>
            if @_audio.currentTime - @_elapsed > @_loaded[0].duration
                # we're done with this segment
                @_elapsed += @_loaded[0].duration
                @_loaded.shift()
                @_loadNext()
        , 1000

    #----------

    _load: (seg) ->
        return false if !seg

        obj = seg:seg, source:null, duration:( seg.get("duration") / 1000 )

        @_loaded.push obj

        obj.seg.audio (err,buffer) =>
            if err
                console.log "Aborting AudioManager._load: #{err}"
                return false

            @_append buffer

            console.log "Loaded audio for #{seg.id}"

            @_loadNext(seg)

    _loadNext: (seg)->
        return if @_loaded.length >= 3
        lastSeg = if @_loaded.length > 0 then @_loaded[@_loaded.length-1].seg else seg
        @_load Segments.Segments.segmentAfter(lastSeg)

#----------

module.exports = class AudioManager
    constructor: ->
        _.extend(@, Backbone.Events)

        @_player = null

        @dispatchToken = Dispatcher.register (payload) =>
            switch payload.actionType
                when 'audio-play'
                    @play payload.ts
                when 'audio-stop'
                    @stop()

        @_playheadFunc = (ts) =>
            @trigger "playhead", ts

    playing: ->
        @_player?

    play: (ts) ->
        @stop() if @_player

        @_player = new SegmentPlayer ts
        @_player.play()
        @_player.on "playhead", @_playheadFunc

    stop: ->
        @_player?.stop()
        @_player?.off()
        @_player = null
        @trigger "playhead", null
