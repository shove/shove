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
# and from the shove network.
# The transport layer also handles encoding
# and decoding of the shove frames.
class Transport
  constructor: (@network, @secure) ->
    @queue = []
    @state = "DISCONNECTED"
    @callbacks = {}
    @connections = 0
    @forcedc = false
    @hosts = null
  
  requestHosts: () ->
    injectScript("hostlookup", "http://api-dev.shove.io:4000/#{@network}/nodes") 
  
  updateHosts: (hosts) ->
    removeScript("hostlookup")
    if hosts
      @hosts = hosts
      @connect()
    else
      @dispatch("error", "No hosts found for network #{@network}")
    
  host: ->
    @hosts[@connections % @hosts.length]
  
  # Bind an event to a function callback
  # `event` options:
  # connect
  # connecting
  # disconnect
  # message
  # reconnect
  # error
  # `cb` the callback to execute on event
  on: (event, cb) ->
    if transportEvents.indexOf(event) == -1
      console.error("Unknow event #{event}.  Valid events: #{transportEvents.join(", ")}")
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
    unless @forcedc
      setTimeout((=> @connect), 5000)
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
  constructor: (network, secure) ->
    super(network, secure)

  # Override
  connect: ->
    # skip if we are connected
    if @state == "CONNECTED"
      return

    # do a host lookup
    unless @hosts
      @dispatch("hostlookup")
      @requestHosts()
      return
       
    @dispatch("connecting")
    @socket = new WebSocket(
      "#{if @secure then "wss" else "ws"}://#{@host()}.shove.io/#{@network}")
    @socket.onclose = => @disconnected()
    @socket.onmessage = (e) => @process(e)
    @socket.onopen = => @connected()
    @forcedc = false
  
  # Override
  disconnect: ->
    @forcedc = true
    @socket.close()
  
  # Override
  transmit: (frame) ->
    @socket.send(frame)


#### CometTransport

# Transport that utilizes JSONP Comet for
# clients that do not support WebSockets  
class CometTransport extends Transport
  constructor: (network, secure) ->
    super(network, secure)
    @seed = 1
    @started = null
    @requesting = false
    @timeout = 10000
    @timer = null
    window["_scb"] = (event) => @onLoad(event)

  connect: ->
    @url = "#{if @secure then "https" else "http"}://poll-#{@host()}.shove.io/#{@network}"
    @request()

  request: (data) ->
    clearTimeout(@timer)
    @timer = setTimeout((() => @onTimeout()), @timeout)
    @addTag(@getUrl())

  addTag: (url) -> injectScript("comet#{@seed}", url)

  # remove the script tag from the dom
  # to prevent possible memory leaks
  # Note: does not stop the request on a unfinished request (some browsers?)
  removeTag: -> removeScript("comet#{@seed++}")

  # Get the request url, based on pending messages,
  # randomness, and subscriber.
  getUrl: ->
    suffix = "/" + Math.random();
    if @queue.length > 0
      suffix += "/" + @queue.shift();
    "#{@url}#{suffix}"

  # Called by JSONP script
  onLoad: (data) ->
    if data == "connect"
      @connected()
    else
      @process({
        data: data
      })

    clearTimeout(@timer);
    @timer = setTimeout((=> @request()), 20);

  # Called by a timer (possibly remove?)
  onTimeout: ->
    @removeTag()
    @request()

  # Stop current request and send another
  transmit: (message) ->
    @removeTag()
    @request(message)


