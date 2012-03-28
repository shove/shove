# Shove Copyright 2012 Shove under the MIT License <http://www.opensource.org/licenses/mit-license.php>

if(typeof exports != "undefined" && exports != null)
  root = exports
else
  root = window

# Opcodes
ERROR = 0x00
CONNECT = 0x01
CONNECT_GRANTED = 0x02
CONNECT_DENIED = 0x03
DISCONNECT = 0x04
DISCONNECT_COMPLETE = 0x06
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

shoveLog = (args...) ->
  console.log.apply(console,[this.constructor.name,"|"].concat(args))

debugLog = (context,args...) ->
  if context.debugging()
    shoveLog.apply(context,args)

#
# Channel
#

SUBSCRIBING_STATE = 0x1
SUBSCRIBED_STATE = 0x2
UNSUBSCRIBED_STATE = 0x3
UNSUBSCRIBING_STATE = 0x4
UNAUTHORIZED_STATE = 0x5

class Channel

  constructor: (@name, @transport) ->
    @state    = UNSUBSCRIBED_STATE
    @filters  = []
    @events   = {
      "message"       : []
      "subscribing"   : []
      "subscribe"     : []
      "unsubscribing" : []
      "unsubscribe"   : []
      "unauthorized"  : []
    }
    @on("subscribing"   , (e) => @state = SUBSCRIBING_STATE)
    @on("subscribe"     , (e) => @state = SUBSCRIBED_STATE)
    @on("unsubscribe"   , (e) => @unsubscribed())
    @on("unsubscribing" , (e) => @state = UNSUBSCRIBING_STATE)
    @on("unauthorized"  , (e) => @state = UNAUTHORIZED_STATE)
    @ready = true
  
  debugging: () ->
    debugging

  # Bind a function to an event
  # The function will be called when
  # any message with event matching event
  # is received
  # `event` the event to trigger on
  # `cb` the callback to execute on trigger
  on: (event, cb) ->
    unless @events.hasOwnProperty(event)
      console.error("Illegal event '#{event}' defined on shove channel")
    else
      @events[event].push(cb)
      if @state == UNSUBSCRIBED_STATE && @ready
        @subscribe()
    debugLog(this,"on; bind event",event,@events[event])
    this
  
  # Trigger an event
  trigger: (event, args...) ->
    if @events.hasOwnProperty(event)
      for cb in @events[event]
        cb.apply(root, args)
    debugLog(this,"trigger; event",event)
    this

  
  # Process an event to all bound listeners
  # `message` the data package
  process: (data, from) ->
    if @filters.length > 0
      for filter in @filters
        data = filter(data)
        if data == false
          return this
    
    @trigger("message", data, from)
    this
  
  
    
  # Publish an event and message on this
  # channel
  # `event` the event to broadcast
  # `message` the message to broadcast
  publish: (message) ->
    @transport.send({
      opcode: PUBLISH,
      channel: @name,
      data: message
    })
    debugLog(this,"publish",message)
    this

  # Unsubscribe from this channel
  unsubscribe: ->
    @trigger("unsubscribing")
    @transport.send({
      opcode: UNSUBSCRIBE,
      channel: @name
    })
    this

  # Register this channel with shove
  subscribe: ->
    @trigger("subscribing")
    @transport.send({
      opcode: SUBSCRIBE,
      channel: @name
    })
    this


  unsubscribed: ->
    @state  = UNSUBSCRIBED_STATE
    @events = null
    @ready  = false

  # Add a message filter.  Message filters are called
  # before any events propogate, so that you can apply
  # logic to every message on every channel.
  #
  # Example:
  # Shove.filter(function(e) {
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

# Available events
TransportEvents = [
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
class Transport

  constructor: (@app, @secure, @hosts=[]) ->
    @errors = []
    @queue = []
    @state = DISCONNECTED_STATE
    @callbacks = {}
    @connections = 0
    @forcedc = false

  debugging: () ->
    debugging

  # Get the URL of the transport
  url: () ->
    "#{if @secure then "wss" else "ws"}://#{@host()}/#{@app}"

  requestHosts: () ->
    injectScript("hostlookup", "http://api.shove.io/apps/#{@app}/nodes") 
  
  updateHosts: (hosts) ->
    removeScript("hostlookup")
    if hosts
      @hosts = hosts
      @connect()
    else
      @trigger("error", "No hosts found for app #{@app}")
    
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
    if TransportEvents.indexOf(event) == -1
      console.error("Unknown event #{event}.  Valid events: #{TransportEvents.join(", ")}")
    else
      unless @callbacks[event]
        @callbacks[event] = []
      @callbacks[event].push(cb)

  # Send data on the transport
  # `data` - the data to send
  send: (data) ->
    unless @state == CONNECTED_STATE
      @queue.push(data)
    else
      @transmit(@encode(data))
    this
              
  #### Private methods

  # trigger an event to all bound callbacks
  trigger: (event, args...) ->
    if @callbacks[event]
      for callback in @callbacks[event]
        callback.apply(root, args)
    this
          
  opened: () ->
    @trigger("connecting")
    connectMessage = 
      opcode:CONNECT
      data:@id
    @transmit(@encode(connectMessage))
  
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
    @socket.send(frame)
  
  decode: (msg) ->
    JSON.parse(msg)

  encode: (msg) ->
    JSON.stringify(msg)
    
  # Override
  connect: (@id = null) ->
    # skip if we are connected
    if @state != DISCONNECTED_STATE
      return

    if WebSocket == undefined
      @trigger("failure")
      @state = FAILURE_STATE

    # do a host lookup
    if @hosts.length == 0
      @trigger("hostlookup")
      @requestHosts()
      return

    @socket = new WebSocket(@url())

    # On open, trigger connecting, set state
    # and send connect event
    @socket.onopen = () =>
      @state = HANDSHAKING_STATE
      @trigger("handshaking")
      @transmit(@encode({
        opcode: CONNECT
        data: @id
      }))

      
    @socket.onclose = () =>
      @state = DISCONNECTED_STATE
      @trigger("disconnect")
      unless @forcedc
        setTimeout((() =>
          @connect()), 2000)    

    @socket.onmessage = (e) =>
      @trigger("message", @decode(e.data))

    @state = CONNECTING_STATE
    @trigger("connecting")
    @forcedc = false


#
# Client
#

class Client

  Version: "1.0.1"

  constructor: () ->
    @id = null
    @app = null
    @secure = false
    @transport = null
    @listeners = {}
    @channels = {}
    @authorized = false
    @hosts = []
  
  debugging: () ->
    debugging

  enableDebugging: () ->
    debugging = true
    this
  
  disableDebugging: () ->
    debugging = false
    this
    
  # Connect to an app
  # `app` The name of the app
  # `opts` The opts
  connect: (@app, opts) ->
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
      @transport.connect(@id)

    debugLog(this,"connect",arguments)
    
    this
       
  # Disconnect from current app
  disconnect: () ->
    @transport.disconnect()
    debugLog(this,"disconnect")
    this

  # Return a channel object for a given app
  # and subscribe to it on the remote host if not
  # currently subscribed
  # `name` The name of the channel
  channel: (name) ->
    unless channel = @channels[name]
      channel = new Channel(name,@transport)
      @channels[name] = channel
    channel

  # Add a app event listener
  # `event` The name of the event
  # `cb` The callback function to call
  on: (event, cb) ->
    unless @listeners.hasOwnProperty(event)
      @listeners[event] = []
    @listeners[event].push(cb)
    debugLog(this,"on; bind event",event,@listeners[event])
    this

  # The identity of the current shove session
  identity: () ->
    @id

  # Send a message directly to another on the app
  # `message` the event data
  # publish: (channel, message) ->
  #   @transport.send({
  #     opcode: PUBLISH,
  #     channel: channel,
  #     data: message
  #   })
  #   this

  # Self authorize to permit all
  # actions on the connection
  authorize: (appKey) ->
    @appKey = appKey
    @transport.send({
      opcode: AUTHORIZE,
      channel: "*",
      data: @appKey
    })
    this

  setHosts: (hosts) ->
    @transport.updateHosts(hosts)

  # Process a shove message
  process: (e) ->
    chan = @channels[e.channel]
    switch e.opcode
      when CONNECT_GRANTED
        @id = e.data
        @transport.connected(e)
        @trigger("connect", e.data)
        debugLog(this,"process; CONNECT_GRANTED",@id)
      when SUBSCRIBE_GRANTED
        chan.trigger("subscribe", e.data)
        debugLog(this,"process; SUBSCRIBE",chan.name)
      when UNSUBSCRIBE_COMPLETE
        chan.trigger("unsubscribe", e.data)
        debugLog(this,"process; UNSUBSCRIBE_COMPLETE",chan.name)
      when SUBSCRIBE_DENIED
        chan.trigger("unauthorized", e.data)
        debugLog(this,"process; SUBSCRIBE_DENIED",chan.name)
      when PUBLISH
        chan.process(e.data, e.from)
        debugLog(this,"process; PUBLISH",chan.name,e.from,e.data)
      when AUTHORIZE_GRANTED
        @authorized = true
        @trigger("authorize", e.data)
        debugLog(this,"process; AUTHORIZE_GRANTED")
      when AUTHORIZE_DENIED
        @authorized = false
        @trigger("authorize_denied")
        debugLog(this,"process; AUTHORIZE_DENIED")
      when ERROR
        console.error(e.data)
      else
        return
    this
    

  # Dispatch event to listeners
  trigger: (event, args...) ->
    if @listeners[event]
      for callback in @listeners[event]
        callback.apply(root, args)
    this
  
  onReconnect: () ->
    for name, channel of @channels
      channel.subscribe()
    @trigger("reconnect")


root.$shove = new Client()
