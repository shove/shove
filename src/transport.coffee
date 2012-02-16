# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License

transportEvents = [
  "connect"
  "connecting"
  "disconnect"
  "message"
  "reconnect"
  "error"
  "statechange"
  "hostlookup"
]

# Script tag helpers
head = document.getElementsByTagName("head")[0]
injectScript = (id, url) ->
  script = document.createElement("script")
  script.setAttribute("src", url)
  script.setAttribute("type", "text/javascript")
  script.setAttribute("id", id)
  head.appendChild(script)

removeScript = (id) -> head.removeChild(document.getElementById(id))

#### Transport

# Base class for transporting data to
# and from the shove app.
# The transport layer also handles encoding
# and decoding of the shove frames.
class Transport
  constructor: (@app, @secure) ->
    @queue = []
    @state = "DISCONNECTED"
    @callbacks = {}
    @connections = 0
    @forcedc = false
    @hosts = ["shove.dev:9000"]
  
  requestHosts: () ->
    injectScript("hostlookup", "http://shove.dev:8080/apps/#{@app}/nodes") 
  
  updateHosts: (hosts) ->
    removeScript("hostlookup")
    if hosts
      @hosts = hosts
      @connect()
    else
      @dispatch("error", "No hosts found for app #{@app}")
    
  host: ->
    @hosts[@connections % @hosts.length]
  
  # Bind an event to a function callback
  # `event` options:
  # connect
  # connecting
  # disconnect
  # message
  # reconnect
  # reconnecting
  # error
  # `cb` the callback to execute on event
  on: (event, cb) ->
    if transportEvents.indexOf(event) == -1
      console.error("Unknown event #{event}.  Valid events: #{transportEvents.join(", ")}")
    else
      unless @callbacks[event]
        @callbacks[event] = []
      @callbacks[event].push(cb)
  
  # Connect the transport to the endpoint
  connect: ->
    console.error("abstract method connect called on transport")
    
  # Disconnect the transport
  disconnect: ->
    console.error("abstract method disconnect called on transport")

  # Send data on the transport
  # `data` - the data to send
  send: (data) ->
    unless @state == "CONNECTED"
      @queue.push(data)
    else
      @transmit(@encode(data))
    this
              
  #### Private methods

  # Dispatch an event to all bound callbacks
  dispatch: (event, args...) ->
    if @callbacks[event]
      for callback in @callbacks[event]
        callback.apply(window, args)
    this
          
  # Process the message event
  process: (msg) ->
    @dispatch("message", @decode(msg.data))
    
  opened: () ->
    @dispatch("connecting")
    connectMessage = 
      opcode:CONNECT
      data:@id
    @transmit(@encode(connectMessage))
  
  # Connected handler
  connected: (e) ->
    @state = "CONNECTED"
    @connections++
    
    if @connections > 1
      @dispatch("reconnect")
    else
      @dispatch("connect")
    
    while @queue.length > 0
      @send(@queue.shift())
    
    this

  # Disconnection handler
  disconnected: ->
    @state = "DISCONNECTED"
    @dispatch("disconnect")

    closed = () =>
      @connect()
    
    unless @forcedc
      setTimeout(closed, 2000)
    this
    
  # Transmit data
  # `data` the encoded data to send
  transmit: (data) ->
    console.error("Transport does not support sending frames.")
  
  # Don't touch unless you understand this
  # completely.. it needs to be cleaned up though
  # possibly bring down the internal binary protocol?
  # `msg` the encoded message to decode
  decode: (msg) ->
    JSON.parse(msg)

  # encode a shove message for the wire
  # `msg` the shove message object
  encode: (msg) ->
    JSON.stringify(msg)

#### WebSocketTransport

# Transport that utilizes native WebSockets or
# a custom version of Flash WebSockets
class WebSocketTransport extends Transport
  constructor: (app, secure) ->
    super(app, secure)

  # Override
  connect: (@id = null) ->
    # skip if we are connected
    if @state == "CONNECTED"
      return

    # do a host lookup
    unless @hosts
      @dispatch("hostlookup")
      @requestHosts()
      return

    @socket = new WebSocket(
      "#{if @secure then "wss" else "ws"}://#{@host()}/#{@app}")
    @socket.onopen = => @opened()
    @socket.onclose = => @disconnected()
    @socket.onmessage = (e) => @process(e)

    @forcedc = false

  # Override
  disconnect: ->
    @forcedc = true
    @socket.close()
  
  # Override
  transmit: (frame) ->
    @socket.send(frame)


