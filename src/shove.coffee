# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License

class Client
  constructor: () ->
    @transport = null
    @url = null
    @channels = {}
    @network = null
    @events = {}
    @id = null
    @debugMode = false
    @secure = false
  

  # Connect to a network
  # `network` The name of the network
  connect: (network) ->
    @network = network
    unless @transport && @transport.state == "CONNECTED"
      if window.WebSocket == undefined
        @transport = new CometTransport(@network, @secure)
      else	  
        @transport = new WebSocketTransport(@network, @secure)
      @transport.on("message", () => @_process.apply(this, arguments))
      @transport.on("connect", () => @_dispatch("connect"))
      @transport.on("connecting", () => @_dispatch("connecting"))
      @transport.on("reconnect", () => @_reconnect())
      @transport.on("disconnect", () => @_dispatch("disconnect"))
      @transport.connect();
    this
       
  # Disconnect from current network
  disconnect: ->
    @transport.disconnect()
    this

  # Return a channel object for a given network
  # and subscribe to it on the remote host if not
  # currently subscribed
  # `name` The name of the channel
  channel: (name) ->
    unless @channels[name]
      @channels[name] = new Channel(name, @transport)
    @channels[name]

  # Add a network event listener
  # `event` The name of the event
  # `cb` The callback function to call
  on: (event, cb) ->
    unless @events[event]
      @events[event] = []
    @events[event].push(cb)
    this

  # The identity of the current shove session
  identity: ->
    @id

  # Toggle debugging
  # `option` true or false
  debug: (option) ->
    @debugMode = option || true
    this

  # Send a message directly to another on the network
  # `client` the client identity to send to
  # `event` the event to trigger remotely
  # `message` the event data
  direct: (client, event, message) ->
    @transport.send({
      event: event,
      to: client,
      data: message
    })
    this

  setAvailableNodes: (nodes) -> @transport.updateHosts(nodes)

  # Process a shove message
  _process: (e) ->
    if e.channel
      if @channels[e.channel]
        @channels[e.channel].process(e.event, e.data, e.from)
      else
    else if e.event == "$error"
      @_dispatch("error", e.data)
    else if e.event == "$identity"
      @id = e.data
      @_dispatch("identity", @id)
    else
      console.error("Unrecognized frame", e)

  # Dispatch event to listeners
  _dispatch: (event, args...) ->
    if @events[event]
      for callback in @events[event]
        callback.apply(window, args)
    this
  
  _reconnect: () ->
    for name, channel of @channels
      channel.subscribe()
    @_dispatch("reconnect")
        
# Create the global Shove object
window.Shove = new Client()

if window.jQuery
  $(() -> $.shove = window.Shove)

# Add console for browsers that suck
(() ->
  console = window.console
  unless console && console.log && console.error
    console =
      log: ->
      error: ->
)()
