# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License
ERROR = 0x00

# Connection
CONNECT = 0x01
CONNECT_GRANTED = 0x02
CONNECT_DENIED = 0x03
DISCONNECT = 0x04
DISCONNECT_COMPLETE = 0x06
  
# Subscribe Ops
SUBSCRIBE = 0x10 
SUBSCRIBE_GRANTED = 0x11
SUBSCRIBE_DENIED = 0x12
UNSUBSCRIBE = 0x13
UNSUBSCRIBE_COMPLETE = 0x14
  
# Publish Ops
PUBLISH = 0x20 
PUBLISH_DENIED = 0x21
PUBLISH_GRANTED = 0x22
  
# Authorize Ops
GRANT_PUBLISH = 0x30 
GRANT_SUBSCRIBE = 0x31
GRANT_CONNECT = 0x32
GRANT_CONTROL = 0x33
  
# Deny Ops
DENY_PUBLISH = 0x40 
DENY_SUBSCRIBE = 0x41
DENY_CONNECT = 0x42
DENY_CONTROL = 0x43
  
# Log Ops
LOG = 0x50 
LOG_STARTED = 0x51
LOG_DENIED = 0x52
  
# Self authorize
AUTHORIZE = 0x60
AUTHORIZE_GRANTED = 0x61
AUTHORIZE_DENIED = 0x62
    
# Presence Ops
PRESENCE_SUBSCRIBED = 0x70
PRESENCE_UNSUBSCRIBED = 0x71
PRESENCE_LIST = 0x72


class Client
  
  constructor: () ->
    @id = null
    @url = null
    @app = null
    @secure = false
    @socket = null
    @listeners = {}
    @channels = {}
    @authorized = false
    @app_key = ''
    
  # Connect to an app
  # `app` The name of the app
  connect: (app, opts) ->
    
    if opts?
      for own key, val of opts
        @[key] = val

    @app = app

    unless @socket && @socket.state == "CONNECTED"
      if window.WebSocket != undefined
        @socket = new WebSocketTransport(@app, @secure)
        @socket.on("message", () => @process.apply(this, arguments))
        @socket.on("connect", () => @trigger("connect"))
        @socket.on("connecting", () => @trigger("connecting"))
        @socket.on("disconnect", () => @trigger("disconnect"))
        @socket.on("reconnect", () => @onReconnect())
        @socket.connect(@id)
    
    this
       
  # Disconnect from current app
  disconnect: () ->
    @socket.disconnect()
    this

  # Return a channel object for a given app
  # and subscribe to it on the remote host if not
  # currently subscribed
  # `name` The name of the channel
  channel: (name) ->
    unless channel = @channels[name]
      channel = new Channel(name, @socket)
      @channels[name] = channel
      @trigger("subscribing",{})
      channel.subscribe()
    channel

  # Add a app event listener
  # `event` The name of the event
  # `cb` The callback function to call
  on: (event, cb) ->
    unless @listeners[event]
      @listeners[event] = []
    @listeners[event].push(cb)
    this

  # The identity of the current shove session
  identity: () ->
    @id

  # Send a message directly to another on the app
  # `client` the client identity to send to
  # `event` the event to trigger remotely
  # `message` the event data
  publish: (channel, message) ->
    @socket.send({
      opcode: PUBLISH,
      channel: channel,
      data: message
    })
    this

  # Self authorize to permit all
  # actions on the connection
  authorize: () ->
    @socket.send({
      opcode: AUTHORIZE,
      channel: "*",
      data: @app_key
    })
    this

  setHosts: (hosts) -> @socket.updateHosts(hosts)

  # Process a shove message
  process: (e) ->
    chan = @channels[e.channel]
    switch e.opcode
      when CONNECT_GRANTED then @id = e.data
      when SUBSCRIBE_GRANTED then chan.trigger("subscribe",e)
      when UNSUBSCRIBE_COMPLETE then chan.trigger("unsubscribe",e)
      when SUBSCRIBE_DENIED then chan.trigger("unauthorize",e)
      when PUBLISH then chan.process(e)
      when AUTHORIZE_GRANTED then @authorized = true
      when ERROR then console.error(e.data)
      else
        return
    @trigger(e.event, e.data)

  # Dispatch event to listeners
  trigger: (event, args...) ->
    if @listeners[event]
      for callback in @listeners[event]
        callback.apply(window, args)
    this
  
  onReconnect: () ->
    for name, channel of @channels
      channel.subscribe()
    @trigger("reconnect")

# Create the global Shove object
window.$shove = new Client()

if window.jQuery
  $(() -> $.shove = window.$shove)

(() ->
  unless window.console && window.console.log
    window.console =
      log: ->
      error: ->
)()
