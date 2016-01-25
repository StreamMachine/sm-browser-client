Backbone = require("backbone")
Dispatcher = require("./dispatcher")

Segment = class extends Backbone.Model
    constructor: (data,opts) ->
        for ts in ['ts','end_ts','ts_actual','end_ts_actual']
            data["_#{ts}"] = data[ts]
            data[ts] = new Date(data[ts])

        super data, opts

    audio: (cb) ->
        if @_audio
            cb null, @_audio
        else
            url = "#{@collection.uriBase}/ts/#{@id}.aac"
            console.log "Fetching #{url}"
            xhr = new XMLHttpRequest()
            xhr.open "GET", url, true
            xhr.responseType = "arraybuffer"

            xhr.onload = (err) =>
                if xhr.status != 200
                    console.log "Error fetching segment audio: #{ err }"
                    cb err
                else
                    console.log "Successful request for #{url}"
                    # if @collection?.audio?
                    #     # convert into audio buffer
                    #     console.log "Calling decoder", xhr.response
                    #     @collection.audio.decodeAudioData xhr.response, (buffer) =>
                    #         @_audio = buffer
                    #         console.log "Providing decoded audio for #{url}"
                    #         cb null, @_audio
                    #     , (err) =>
                    #         cb new Error "Error decoding audio: #{err}"
                    # else
                    @_audio = xhr.response #new Uint8Array(xhr.response)
                    cb null, @_audio

            xhr.send()


            true

    #----------

    waveform: (cb) ->
        if @_waveform
            cb null, @_waveform
        else
            $.getJSON "#{@collection.uriBase}/waveform/#{@attributes.id}", (data) =>
                @_waveform = WaveformData.create(data)
                cb null, @_waveform

    #----------

    downsampled_wave: (width,cb) ->
        if width <= @attributes.preview.length
            cb null, WaveformData.create(@attributes.preview).resample(width)
        else
            @waveform (err,full_wave) =>
                if err
                    cb err
                else
                    cb null, full_wave.resample(width)

#----------

SegmentsCollection = class extends Backbone.Collection
    model: Segment

    comparator: (seg) -> Number(seg.get('ts'))

    findByTimestamp: (ts) ->
        @find (s) -> Number(s.attributes.ts_actual) <= Number(ts) < Number(s.attributes.end_ts_actual)

    segmentAfter: (seg) ->
        idx = @indexOf seg

        if @length > idx + 1
            @at(idx + 1)
        else
            null

    selectDates: (begin_date,end_date) ->
        #console.log "selectDates called for ", begin_date, end_date
        @filter (s) ->
            #console.log "testing #{s.id}", s.attributes.ts, s.attributes.end_ts, begin_date, end_date
            (s.attributes.ts > begin_date && s.attributes.ts < end_date) || (s.attributes.end_ts < end_date && s.attributes.end_ts > begin_date)

    previewWave: ->
        # create a waveformdata by concatanating the previews from each
        # segment

        return @_preview if @_preview

        data = []
        data.push seg.attributes.preview.data... for seg in @models

        #console.log "pW seg data is ", data

        p = WaveformData.create
            version: 1
            samples_per_pixel: @models[0].attributes.preview.samples_per_pixel
            length: data.length / 2
            sample_rate: @models[0].attributes.preview.sample_rate
            data: data

        @_preview = p

#----------

Segments = new SegmentsCollection
FocusSegments = new SegmentsCollection

module.exports =
    Segments: Segments
    Focus: FocusSegments
