zlib = require 'zlib'
dgram = require 'dgram'

exports = module.exports = (host, port, options) ->
  new Gelfling host, port, options

exports.Gelfling = class Gelfling

  constructor: (@host = 'localhost', @port = 12201, options = {}) ->
    @maxChunkSize = @_getMaxChunkSize options.maxChunkSize
    @defaults = options.defaults ? {}


  send: (data, callback = ->) ->
    data = [data] if Buffer.isBuffer data

    unless data instanceof Array
      return @encode @convert(data), (err, chunks) =>
        return callback err if err
        @send chunks, callback

    udpClient = dgram.createSocket 'udp4'
    remaining = data.length
    for chunk in data
      udpClient.send chunk, 0, chunk.length, @port, @host, (err) ->
        return callback err if err
        if --remaining is 0
          udpClient.close()
          callback()


  encode: (msg, callback = ->) ->
    zlib.gzip new Buffer(JSON.stringify msg), (err, compressed) =>
      return callback err if err
      callback null, @split(compressed)


  HEADER_SIZE = 12

  split: (data, chunkSize = @maxChunkSize) ->
    return [data] if data.length <= chunkSize

    msgId = @_newMsgId()
    numChunks = Math.ceil data.length / chunkSize
    console.log "Size is #{data.length}, splitting into #{numChunks} chunks"
    for chunkIx in [0...numChunks]
      dataStart = chunkIx * chunkSize
      dataEnd = Math.min dataStart + chunkSize, data.length
      chunk = new Buffer HEADER_SIZE + (dataEnd - dataStart)
      chunk[0] = 0x1e
      chunk[1] = 0x0f
      msgId.copy chunk, 2 # msg ID goes after the Gelf ID
      chunk[10] = chunkIx
      chunk[11] = numChunks
      data.copy chunk, HEADER_SIZE, dataStart, dataEnd
      console.log "Created chunk #{chunkIx}"
      chunk


  GELF_KEYS = ['version', 'host', 'short_message', 'full_message', 'timestamp', 'level', 'facility', 'line', 'file']
  ILLEGAL_KEYS = ['_id']

  convert: (msg) ->
    msg = {short_message: msg} if typeof msg isnt 'object'

    gelfMsg = {}

    # Default fields
    for own key, val of @defaults
      gelfMsg[key] = if typeof val is 'function' then val(msg) else val

    # Msg fields
    for own key, val of msg
      key = '_' + key unless key in GELF_KEYS
      key = '_' + key if key in ILLEGAL_KEYS
      gelfMsg[key] = val

    # Required fields
    gelfMsg.version ?= '1.0'
    gelfMsg.host ?= require('os').hostname()
    gelfMsg.timestamp ?= +new Date / 1000
    gelfMsg.short_message ?= JSON.stringify msg

    gelfMsg


  _newMsgId: ->
    msgId = new Buffer 8
    msgId.writeUInt32LE Math.random() * 0x100000000, 0, true
    msgId.writeUInt32LE Math.random() * 0x100000000, 4, true
    msgId


  _getMaxChunkSize: (size = 'wan') ->
    switch size.toLowerCase()
      when 'wan' then 1420
      when 'lan' then 8154
      else parseInt size




msg =
  short_message: "Message at #{+new Date}"
  #full_message: "start/#{new Buffer(20000).toString 'base64'}/end".replace /\//g, "\n"
  id: 34
  some_other_field: "Dude!\nIt's a multi line\nMessage!"
  full_message: {a: 1, b: 2}
  obj_field: {a: 1, b: 2}
  file: '/usr/home/thing.js'
  #line: 345

  #exports().send "Message at #{+new Date}", (err) -> console.log "all done"
exports('localhost', 12201, defaults: {line: () -> Math.round(Math.random() * 100)}).send msg, (err) -> console.log "all done"

