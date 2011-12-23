# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License


ERROR = 0

# App ops 1-20
DEBUG = 1
PERMIT_CONNECT = 2
PERMIT_DEBUG = 3

# Channel ops 21-40
PUBLISH = 21
PUBLISH_PERMITTED = 22
SUBSCRIBE = 23
UNSUBSCRIBE = 24
PERMIT_PUBLISH = 25
PERMIT_SUBSCRIBE = 26
PRESENCE_SUBSCRIBE = 27
PRESENCE_UNSUBSCRIBE = 28
PRESENCE_LIST = 29

# Subscriber ops 41-60
SET_IDENTITY = 41
PUBLISH_DENIED = 42
SUBSCRIBE_COMPLETE = 43
SUBSCRIBE_DENIED = 44
UNSUBSCRIBE_COMPLETE = 45
DEBUG_DENIED = 46
DEBUG_PERMITTED = 47
CONNECT_DENIED = 48
CONNECT_PERMITTED = 49
DIRECT = 50
DIRECT_DENIED = 51
DIRECT_PERMITTED = 52
PERMIT_ADMIN = 53

class Client
  
  constructor: () ->
    @transport = null
    @url = null
    @channels = {}
    @app = null
    @events = {}
    @id = null
    @secure = false
    @authorized = true
  

  # Connect to a app
  # `app` The name of the app
  connect: (app, opts) ->
    
    if opts?
      for own key, val of opts
        @[key] = val

    @app = app
    unless @transport && @transport.state == "CONNECTED"
      if window.WebSocket == undefined
        @transport = new CometTransport(@app, @secure)
      else	  
        @transport = new WebSocketTransport(@app, @secure)
      @transport.on("message", () => @_process.apply(this, arguments))
      @transport.on("connect", () => @_dispatch("connect"))
      @transport.on("connecting", () => @_dispatch("connecting"))
      @transport.on("reconnect", () => @_reconnect())
      @transport.on("disconnect", () => @_dispatch("disconnect"))
      @transport.connect();
    this
       
  # Disconnect from current app
  disconnect: ->
    @transport.disconnect()
    this

  # Return a channel object for a given app
  # and subscribe to it on the remote host if not
  # currently subscribed
  # `name` The name of the channel
  channel: (name) ->
    unless @channels[name]
      @channels[name] = new Channel(name, @transport)
    @channels[name]

  # Add a app event listener
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
  debug: (fn) ->
    log.callback = fn
    @transport.send({
      opcode: DEBUG
    })
    this

  # Send a message directly to another on the app
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

  setPublisherKey: (key) ->
    @transport.send({
      opcode: PERMIT_ADMIN,
      data: key
    })
    this

  setAvailableNodes: (nodes) -> @transport.updateHosts(nodes)

  # Process a shove message
  _process: (e) ->
    console.log(e)
    chan = @channels[e.channel]
    switch e.opcode
      when SET_IDENTITY then @id = e.data
      when SUBSCRIBE_COMPLETE then chan.transition("subscribed")
      when UNSUBSCRIBE_COMPLETE then chan.transition("unsubscribed")
      when SUBSCRIBE_DENIED then chan.transition("unauthorized")
      when PRESENCE_SUBSCRIBE then chan.process("presence", "subscribe", e.from)
      when PRESENCE_SUBSCRIBE then chan.process("presence", "unsubscribe", e.from)
      when PUBLISH_PERMITTED then @authorized = true
      when PUBLISH then chan.process(e.event, e.data, e.from)
      when ERROR then 
      else
        return
    @_dispatch(e.event, e.data)

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
