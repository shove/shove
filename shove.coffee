global = exports ? this : window

((root) ->

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
  # Transport
  #

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

  # Transport class, abstracts the WebSocket
  # and some other events
  class Transport

    constructor: (@app, @secure) ->
      @errors = []
      @queue = []
      @state = DISCONNECTED_STATE
      @callbacks = {}
      @connections = 0
      @forcedc = false
      @hosts = ["shove.dev:9000"]

    # Get the URL of the transport
    url: () ->
      "#{if @secure then "wss" else "ws"}://#{@host()}/#{@app}"

    requestHosts: () ->
      injectScript("hostlookup", "http://shove.dev:8080/apps/#{@app}/nodes") 
    
    updateHosts: (hosts) ->
      removeScript("hostlookup")
      if hosts
        @hosts = hosts
        @connect()
      else
        @trigger("error", "No hosts found for app #{@app}")
      
    host: ->
      @hosts[@connections % @hosts.length]


    isConnected: () -> @state == CONNECTED_STATE
    isHandshaking: () -> @state == HANDSHAKING_STATE

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
      unless @hosts
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
        @trigger("message", @decode(e).data)

      @state = CONNECTING_STATE
      @trigger("connecting")
      @forcedc = false




  ###############################
  #
  # Client
  #

  class Client
  
    Version: "1.0.1",

    constructor: () ->
      @id = null
      @app = null
      @secure = false
      @transport = null
      @listeners = {}
      @channels = {}
      @authorized = false
      @app_key = ""
      
    # Connect to an app
    # `app` The name of the app
    # `opts` The opts
    connect: (app, opts) ->
      @app = app      
      if opts?
        for own key, val of opts
          @[key] = val

      unless @transport && @transport.state == "CONNECTED"
        @transport = new Transport()
        @transport.on("failure"    , () => @trigger("failure"))
        @transport.on("message"    , (m) => @process(m))
        @transport.on("connecting" , () => @trigger("connecting"))
        @transport.on("handshaking", () => @trigger("handshaking"))
        @transport.on("connect"    , () => @trigger("connect"))
        @transport.on("disconnect" , () => @trigger("disconnect"))
        @transport.on("reconnect"  , () => @onReconnect())
        @transport.connect(@id)
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
        channel = new Channel(name,@transport)
        # channel.on('subscribing',((e) => @trigger("subscribing",{})))
        channel.subscribe()
        @channels[name] = channel
      channel

    # Add a app event listener
    # `event` The name of the event
    # `cb` The callback function to call
    on: (event, cb) ->
      unless @listeners.hasOwnProperty(event)
        @listeners[event] = []
      @listeners[event].push(cb)
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
    authorize: () ->
      @transport.send({
        opcode: AUTHORIZE,
        channel: "*",
        data: @app_key
      })
      this

    setHosts: (hosts) -> @transport.updateHosts(hosts)

    # Process a shove message
    process: (e) ->
      chan = @channels[e.channel]
      switch e.opcode
        when CONNECT_GRANTED
          @id = e.data
          @transport.connected(e)
          @trigger("connect",e.data)
        when SUBSCRIBE_GRANTED
          chan.trigger("subscribe",e.data)
        when UNSUBSCRIBE_COMPLETE
          chan.trigger("unsubscribe",e.data)
        when SUBSCRIBE_DENIED
          chan.trigger("unauthorized",e.data)
        when PUBLISH
          chan.process(e.data)
        when AUTHORIZE_GRANTED
          @authorized = true
          @trigger("authorize",e.data)
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

)(global)