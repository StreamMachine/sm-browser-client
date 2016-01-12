window.SM_AudioManager = class AudioManager
    constructor: (@ctx,@segments,@cursor) ->
        _.extend(@, Backbone.Events)

        @_playheadTick = null
        @_loadTick = null

        @_elapsed = 0

        @_audio = document.createElement("audio")
        @_source = new MediaSource()
        @_audio.src = window.URL.createObjectURL(@_source)

        @_waiting = []

        @_source.addEventListener "sourceopen", =>
            # FIXME: type needs to get loaded in
            @_sourceBuffer = @_source.addSourceBuffer('audio/mp4; codecs="mp4a.40.2"')
            #@_sourceBuffer = @_source.addSourceBuffer('audio/aac')

            @_sourceBuffer.addEventListener "updateend", =>
                @_ready = true
                @trigger "ready"
                @_fireAppend()

            @_fireAppend()

        # we want to always have three segments loaded... the current one
        # and two after it
        @_loaded = []

        seg = @segments.findByTimestamp(@cursor)
        @_load(seg)

        console.log "AudioManager: cursor / ts_actual", @cursor, seg.get("ts_actual")
        @_initialSeek = (Number(@cursor) - Number(seg.get("ts_actual"))) / 1000
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
            @trigger "playhead", new Date(Number(@cursor) + @_audio.currentTime*1000 - @_initialSeek*1000)
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
        @_load @segments.segmentAfter(lastSeg)
