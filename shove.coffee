# Shove Copyright 2012 Shove under the MIT License <http://www.opensource.org/licenses/mit-license.php>

if typeof exports != "undefined" && exports != null
  root = exports
else
  root = window


root.WEB_SOCKET_SWF_LOCATION ?= "http://cdn.shove.io/WebSocketMainInsecure.swf"

# Opcodes
ERROR = 0x00
CONNECT = 0x01
CONNECT_GRANTED = 0x02
CONNECT_DENIED = 0x03
DISCONNECT = 0x04
DISCONNECT_COMPLETE = 0x06
REDIRECT = 0x07
SET_IDENTITY = 0x08
SUBSCRIBE = 0x10 
SUBSCRIBE_GRANTED = 0x11
SUBSCRIBE_DENIED = 0x12
UNSUBSCRIBE = 0x13
UNSUBSCRIBE_COMPLETE = 0x14
PUBLISH = 0x20 
PUBLISH_DENIED = 0x21
PUBLISH_GRANTED = 0x22
GRANT_PUBLISH = 0x30 
GRANT_SUBSCRIBE = 0x31
GRANT_CONNECT = 0x32
GRANT_CONTROL = 0x33
DENY_PUBLISH = 0x40 
DENY_SUBSCRIBE = 0x41
DENY_CONNECT = 0x42
DENY_CONTROL = 0x43
LOG = 0x50 
LOG_STARTED = 0x51
LOG_DENIED = 0x52
AUTHORIZE = 0x60
AUTHORIZE_GRANTED = 0x61
AUTHORIZE_DENIED = 0x62
PRESENCE_SUBSCRIBED = 0x70
PRESENCE_UNSUBSCRIBED = 0x71
PRESENCE_LIST = 0x72

#
# Debug
#

debugging = false

debug = (args...) ->
  if debugging
    console.log.apply console, args

# 
# Dispatcher
# 
# contains methods for use in binding, unbinding and 
# triggering events
class Dispatcher
  constructor: (@allowedEvents) ->
    @events = {}
    for e in allowedEvents
      @events[e] = []
    
  # Bind events
  # will give an error and will not bind if event name is not allowed
  # e: event name
  # cb: callback function
  on: (e, cb) ->
    unless @events.hasOwnProperty(e)
      console.error("Invalid event binding.  '#{e}' not found in '#{@allowedEvents.join(', ')}'")
      return false
    else
      if typeof cb == 'function'
        unless @events[e].length > 0
          @events[e] = []
        @events[e].push(cb)
      else
        return @events[e]
    this

  # Unbind events
  # e: event name
  # cb: original callback function
  off: (e, cb) ->
    if @events.hasOwnProperty(e)
      for cbi in [(@events[e].length-1)..0]
        if @events[e][cbi] == cb
          @events[e].splice(cbi,1)
    this

  # Trigger events
  # e: event name
  # args...: arguments to be passed to callback functions
  trigger: (e, args...) ->
    if @events.hasOwnProperty(e)
      for cb in @events[e]
        cb.apply(root,args)
    this


#
# Channel
#

SUBSCRIBING_STATE = 0x1
SUBSCRIBED_STATE = 0x2
UNSUBSCRIBED_STATE = 0x3
UNSUBSCRIBING_STATE = 0x4
UNAUTHORIZED_STATE = 0x5

class Channel extends Dispatcher

  constructor: (@name, @transport) ->
    super [
      "message"
      "subscribing"
      "subscribe"
      "unsubscribing"
      "unsubscribe"
      "subscribe_denied"
      "publish_granted"
      "publish_denied"
      "presence_added"
      "presence_removed"
      "presence_list"
    ]

    @state = UNSUBSCRIBED_STATE
    @filters = []

    @on("subscribing", (e) => @state = SUBSCRIBING_STATE)
    @on("subscribe", (e) => @state = SUBSCRIBED_STATE)
    @on("unsubscribe", (e) => @unsubscribed())
    @on("unsubscribing", (e) => @state = UNSUBSCRIBING_STATE)
    @on("subscribe_denied", (e) => @state = UNAUTHORIZED_STATE)

    @ready = true

  # Bind a function to an event
  # The function will be called when
  # any message with event matching event
  # is received
  # `event` the event to trigger on
  # `cb` the callback to execute on trigger
  on: (e, cb) ->
    r = super(e, cb)
    if @events.hasOwnProperty(e) && @state == UNSUBSCRIBED_STATE && @ready
      @subscribe()
    r
  
  # Process an event to all bound listeners
  # `message` the data package
  process: (data, from) ->
    if @filters.length > 0
      for filter in @filters
        data = filter(data, from)
        if data == false
          return this
    @trigger("message", data, from)
    this

  # authenticate with the channel to allow
  # subscription and publishing.
  # key: unique key required to authenticate
  auth: (@key) ->
    @transport.send
      opcode: AUTHORIZE
      channel: @name
      data: @key

  # Alias for auth
  authenticate: (key) -> @auth(key)

  # Deprecated: alias for auth
  authorize: (key) -> @auth(key)
  
  # Publish an event and message on this
  # channel
  # `event` the event to broadcast
  # `message` the message to broadcast
  publish: (message) ->
    @transport.send
      opcode: PUBLISH
      channel: @name
      data: message
    this

  # Unsubscribe from this channel
  unsubscribe: ->
    @trigger "unsubscribing"
    @transport.send
      opcode: UNSUBSCRIBE
      channel: @name
    this

  # Register this channel with shove
  subscribe: ->
    @trigger "subscribing"
    @transport.send
      opcode: SUBSCRIBE
      channel: @name
    this

  unsubscribed: ->
    @state = UNSUBSCRIBED_STATE
    @events = null
    @ready = false

  # Add a message filter.  Message filters are called
  # before any events propogate, so that you can apply
  # logic to every message on every channel.
  #
  # Example:
  # $shove.filter(function(e) {
  #   e.timestamp = new Date();
  #   if(e.timestamp > END_OF_THE_WORLD) {
  #     return false;
  #   }
  #   return e;
  # });
  #
  # The above example will append a timestamp to all
  # messages and also prevent them from propogating
  # by returning false when the END_OF_THE_WORLD date
  # has passed
  #
  # `fn` fn The filter function to call
  filter: (fn) ->
    if typeof fn != 'function'
      return @filters
    @filters.push(fn)
    this


# ------------
# Transport
# ------------

CONNECTED_STATE = 0x1
CONNECTING_STATE = 0x2
DISCONNECTED_STATE = 0x3
HANDSHAKING_STATE = 0x4
FAILURE_STATE = 0x5

injectScript = (id, url) ->
  head = document.getElementsByTagName("head")[0]
  script = document.createElement("script")
  script.setAttribute("src", url)
  script.setAttribute("type", "text/javascript")
  script.setAttribute("id", id)
  head.appendChild(script)

removeScript = (id) ->
  head = document.getElementsByTagName("head")[0]
  head.removeChild(document.getElementById(id))

# Transport class, abstracts the WebSocket
# and some other events
class Transport extends Dispatcher

  constructor: (@app, @secure, @hosts=[]) ->
    super [
      "connect"
      "connecting"
      "disconnect"
      "message"
      "reconnect"
      "error"
      "statechange"
      "failure"
      "handshaking"
    ]
    @errors = []
    @queue = []
    @state = DISCONNECTED_STATE
    @callbacks = {}
    @connections = 0
    @forcedc = false

  # Get the URL of the transport
  url: () ->
    "#{if @secure then "wss" else "ws"}://#{@host()}/v1/#{@app}"

  requestHosts: () ->
    injectScript("hostlookup", "http://api.shove.io/v1/apps/#{@app}/nodes")
  
  updateHosts: (@hosts) ->
    removeScript("hostlookup")
    if @hosts
      @connect()
    else
      @trigger("error", "No hosts found for app #{@app}")
    
  host: ->
    @hosts[@connections % @hosts.length]

  # Send data on the transport
  # `data` - the data to send
  send: (data) ->
    msg = @encode(data)
    unless @state == CONNECTED_STATE
      debug "queuing #{msg}"
      @queue.push(data)
    else
      @transmit(msg)
    this
              
  #### Private methods
            
  # Connected handler
  connected: (e) ->
    @state = CONNECTED_STATE
    @connections++
    
    if @connections > 1
      @trigger("reconnect")
    else
      @trigger("connect")
    
    while @queue.length > 0
      @send(@queue.shift())
    
    this

  disconnect: ->
    @forcedc = true
    @socket.close()
  
  transmit: (frame) ->
    debug "sending #{frame}"
    @socket.send(frame)
  
  decode: (msg) ->
    JSON.parse(msg)

  encode: (msg) ->
    JSON.stringify(msg)
    
  # Override
  connect: (key) ->

    if key
      @connectKey = key

    # skip if we are connected
    if @state != DISCONNECTED_STATE
      return

    if WebSocket == undefined
      @trigger("failure")
      @state = FAILURE_STATE
      return

    # do a host lookup
    if @hosts.length == 0
      @trigger("hostlookup")
      @requestHosts()
      return

    @socket = new WebSocket(@url())

    # On open, trigger connecting, set state
    # and send connect event
    @socket.onopen = () =>
      debug "websocket connected"
      @state = HANDSHAKING_STATE
      @trigger("handshaking")
      @transmit(@encode({
        opcode: CONNECT
        data: @connectKey
      }))

      
    @socket.onclose = () =>
      debug "websocket disconnected"
      @state = DISCONNECTED_STATE
      @trigger("disconnect")
      unless @forcedc
        setTimeout((() =>
          @connect()), 2000)

    @socket.onmessage = (e) =>
      debug "recv #{e.data}"
      @trigger "message", @decode(e.data)

    @state = CONNECTING_STATE
    @trigger("connecting")
    @forcedc = false


#
# Client
#

class Client extends Dispatcher

  Version: "1.0.6"

  constructor: () ->
    super [
      "failure"
      "connecting"
      "handshaking"
      "disconnect"
      "connect"
      "authorize"
      "authorize_denied"
      "reconnect"
    ]
    @id = null
    @app = null
    @secure = false
    @transport = null
    @channels = {}
    @authorized = false
    @hosts = []
  
  debug: (choice) ->
    debugging = choice

  # Connect to an app
  # `app` The name of the app
  # `opts` The opts
  connect: (@app, @connectKey, opts) ->
    if opts?
      for own key, val of opts
        @[key] = val

    unless @transport && @transport.state == "CONNECTED"
      @transport = new Transport(@app, @secure, @hosts)
      @transport.on("failure", () => @trigger("failure"))
      @transport.on("message", (m) => @process(m))
      @transport.on("connecting", () => @trigger("connecting"))
      @transport.on("handshaking", () => @trigger("handshaking"))
      @transport.on("disconnect", () => @trigger("disconnect"))
      @transport.on("reconnect", () => @onReconnect())
      @transport.connect @connectKey
    this
       
  # Disconnect from current app
  disconnect: () ->
    @transport.disconnect()
    this

  # Return a channel object for a given app
  # and subscribe to it on the remote host if not
  # currently subscribed
  # `name` The name of the channel
  channel: (name) ->
    unless channel = @channels[name]
      channel = new Channel(name, @transport)
      @channels[name] = channel
    channel

  # The identity of the current shove session
  identity: () ->
    @id

  # Authenticate with the app to grant
  # client pub/sub rights on all channels
  auth: (@key) -> 
    @transport.send
      opcode: AUTHORIZE
      channel: "*"
      data: @key
    this

  # Deprecated
  authenticate: (key) -> @auth(key)

  # Deprecated: alias for authenticate
  authorize: (key) -> @auth(key)

  # Set the available hosts
  setHosts: (hosts) ->
    @transport.updateHosts(hosts)

  setAvailableHosts: (hosts) ->
    @setHosts(hosts)

  # Process a shove message
  process: (e) ->
    chan = @channels[e.channel]
    switch e.opcode
      
      when CONNECT_GRANTED
        @id = e.data
        @transport.connected(e)
        @trigger("connect", e.data)
      when SUBSCRIBE_GRANTED
        chan.trigger("subscribe", e.data)
      when UNSUBSCRIBE_COMPLETE
        chan.trigger("unsubscribe", e.data)
      when SUBSCRIBE_DENIED
        chan.trigger("subscribe_denied", e.data)
      when PUBLISH
        chan.process(e.data, e.from)
      when PUBLISH_GRANTED
        chan.trigger("publish_granted",e.data)
      when PUBLISH_DENIED
        chan.trigger("publish_denied", e.data)
      when AUTHORIZE_GRANTED
        if typeof chan != 'undefined'
          chan.trigger("publish_granted",e.data)
        else
          @authorized = true
          @trigger("authorize", e.data)
      when AUTHORIZE_DENIED
        if typeof chan != 'undefined'
          chan.trigger("authorize_denied",e.data)
        else
          @authorized = false
          @trigger("authorize_denied") 
      when ERROR
        console.error(e.data)
      when PRESENCE_SUBSCRIBED
        chan.trigger("presence_added", e.from)
      when PRESENCE_UNSUBSCRIBED
        chan.trigger("presence_removed", e.from)
      when PRESENCE_LIST
        chan.trigger("presence_list", e.data.split(","))
      else
        return
    this
    
  onReconnect: () ->
    # TODO: State
    for name, channel of @channels
      channel.subscribe()
    @trigger("reconnect")


root.$shove = new Client()