# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License

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
      event: "debug",
      channel: "$"
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

  authorize: (key) ->
    @transport.send({
      channel: "$",
      event: "authorize",
      data: key
    })
    this   

  setAvailableNodes: (nodes) -> @transport.updateHosts(nodes)

  # Process a shove message
  _process: (e) ->
    if e.channel
      if e.channel == "$"
        switch e.event
          when "identity" then @id = e.data
          when "subscribed" then @channels[e.data].transition("subscribed")
          when "unsubscribed" then @channels[e.data].transition("unsubscribed")
          when "subscribe_unauthorized" then @channels[e.data].transition("unauthorized")
          when "authorized" then @authorized = true
        @_dispatch(e.event, e.data)
      if @channels[e.channel]
        @channels[e.channel].process(e.event, e.data, e.from)
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
