###
Copyright (C) 2011 by Dan Simpson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

host = (() ->
  hosts = ["dev","dev1"]
  itr = 0
  () ->
    hosts[itr++ % hosts.length]
)()

###
Transport

Base class for transporting data to
and from the shove network.

The transport layer also handles encoding
and decoding of the shove frames.

###
_transportEvents = [
  "connect"
  "connecting"
  "disconnect"
  "message"
  "reconnect"
  "error"
]

class Transport
  constructor: () ->
    @queue = []
    @connected = false
    @callbacks = {}
    @connections = 0
    @forcedc = false
  
  ###
  Bind an event to a function callback
  
  @param event
    connect
    connecting
    disconnect
    message
    reconnect
    error
  
  @param cb the callback to execute on event
  ###
  on: (event, cb) ->
    if _transportEvents.indexOf(event) == -1
      console.error("Unknow event #{event}.  Valid events: #{_transportEvents.join(", ")}")
    else
      unless @callbacks[event]
        @callbacks[event] = []
      @callbacks[event].push(cb)
  
  ###
  Connect the transport to the endpoint
  ###
  connect: ->
    console.error("abstract method connect called on transport")
    
  ###
  Disconnect the transport
  ###
  disconnect: ->
    console.error("abstract method disconnect called on transport")

  ###
  Send data on the transport
  @params data - the data to send
  @returns this
  ###
  send: (data) ->
    unless @connected
      @queue.push(data)
    else
      @_send(@_encode(data))
    this
              
  ###
  Private Methods
  ###

  # Dispatch an event to all bound callbacks
  _dispatch: (event, args...) ->
    if @callbacks[event]
      for callback in @callbacks[event]
        callback.apply(window, args)
    this
          
  # Process the message event
  _process: (msg) ->
    @_dispatch("message", @_decode(msg.data))
  
  # Connected handler
  _connected: (e) ->
    @connected = true
    @connections++
    
    if @connections > 1
      @_dispatch("reconnect")
    else
      @_dispatch("connect")
      
    while @queue.length > 0
      @send(@queue.shift())
    
    this

  # Disconnection handler
  _disconnected: ->
    @connected = false
    @_dispatch("disconnect")
    unless @forcedc
      setTimeout((=> @connect), 5000)
    this
    
  # Real send
  _send: (data) ->
    console.error("Transport does not support sending frames.")
  
  ###
  Don't touch unless you understand this
  completely.. it needs to be cleaned up though
  possibly bring down the internal binary protocol?
  ###
  _decode: (msg) ->
    result = {}
    len = msg.length
    idx = 0
    head = 0
    tail = 0

    while head < len
      if msg[head] == "!"
        if idx == 0
          result.channel = msg.substring(tail, head)
        else if idx == 1
          result.event = msg.substring(tail, head)
        else if idx == 2
          result.to = msg.substring(tail, head)
        else
          result.from = msg.substring(tail, head)
          result.data = msg.substring(head + 1, len)
          break
        idx++
        tail = head + 1
      head++
    
    result

  ###
  encode a shove message for the wire
  ###
  _encode: (msg) ->
    "#{msg.channel}!#{msg.event}!#{msg.to || ""}!!#{msg.data || ""}"

###
WebSocketTransport

Transport that utilizes native WebSockets or
a custom version of Flash WebSockets
###
class WebSocketTransport extends Transport
  constructor: (@network, @secure) ->
    super

  # Override
  connect: ->
    @_dispatch("connecting")
    @socket = new WebSocket(
      "#{if @secure then "wss" else "ws"}://ws-#{host()}.shove.io/#{@network}")
    @socket.onclose = => @_disconnected()
    @socket.onmessage = (e) => @_process(e)
    @socket.onopen = => @_connected()
    @forcedc = false
  
  # Override
  disconnect: ->
    @forcedc = true
    @socket.close()
  
  # Override
  _send: (frame) ->
    @socket.send(frame)

###
CometTransport

Transport that utilizes JSONP Comet for
clients that do not support WebSockets
###    
class CometTransport extends Transport
  constructor: (@network, @secure) ->
    super
    @seed = 1
    @started = null
    @requesting = false
    @timeout = 10000
    @timer = null
    window["_scb"] = (event) => @onLoad(event)

  connect: ->
    @url = "#{if @secure then "https" else "http"}://poll-#{host()}.shove.io/#{@network}"
    @request()

  request: (data) ->
    clearTimeout(@timer)
    @timer = setTimeout((() => @onTimeout()), @timeout)
    @addTag(@getUrl())

  addTag: (url) ->
    script = document.createElement("script")
    script.setAttribute("src", url)
    script.setAttribute("type", "text/javascript")
    script.setAttribute("id", "comet" + @seed)
    document.getElementsByTagName("head")[0].appendChild(script)

  ###
  remove the script tag from the dom
  to prevent possible memory leaks
  Note: does not stop the request on a unfinished request (some browsers?)
  ###
  removeTag: ->
    document.getElementsByTagName("head")[0].removeChild(document.getElementById("comet#{@seed++}"))

  ###
  Get the request url, based on pending messages,
  randomness, and subscriber.
  ###
  getUrl: ->
    suffix = "/" + Math.random();
    if @queue.length > 0
      suffix += "/" + @queue.shift();
    "#{@url}#{suffix}"

  ###
  Called by JSONP script
  ###
  onLoad: (data) ->
    if data == "connect"
      @_connected()
    else
      @_process({
        data: data
      })

    clearTimeout(@timer);
    @timer = setTimeout((=> @request()), 20);

  ###
  Called by a timer (possibly remove?)
  ###
  onTimeout: ->
    @removeTag()
    @request()

  ###
  Stop current request and send another
  ###
  send: (message) ->
    @removeTag()
    @request(message)


