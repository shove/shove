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
    #console.log(data)
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
      "#{if @secure then "wss" else "ws"}://#{@host()}/#{@app}")
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


#### MockTransport

# Copy of WebSocketTransport with a mock server
# for testing shove clients
class MockTransport extends Transport
  
  class Server
    constructor: () ->
      @networks = {}
      @clients = []
    
    addNetwork: (networkName) ->
      @networks[networkName] = new Network(networkName)
    
    removeNetwork: (networkName) ->
      delete @networks[networkName]
    
    hasNetwork: (name) ->
      !!@networks[name]

    addClient: () ->
      @clients.push(new Client())
      return @clients.length - 1

    removeClient: (id) ->
      delete @clients[id]

    hasClient: (id) ->
      @clients.indexOf(id) >= 0

    class Client
      constructor: () ->

    class Network
      constructor: (@name) ->
        @channels = {}
        @clients = []
        @authorizers = []
    
      addChannel: (name) ->
        @channels[name] = new Channel(name)
        this
    
      removeChannel: (name) ->
        delete @channels[name]
        this
      
      hasChannel: (name) ->
        !! @channels[name]
    
      addClient: (id) ->
        @clients.push(id)
        this
    
      removeClient: (id) ->
        @removeAuthorizer(id)
        @clients.splice(@clients.indexOf(id),1)
        this
      
      hasClient: (id) ->
        @clients.indexOf(id) >= 0
      
      addAuthorizer: (id) ->
        unless @hasClient(id)
          @addClient(id)
        @authorizers.push(id)
        this
      
      removeAuthorizer: (id) ->
        @authorizers.splice(@authorizers.indexOf(id),1)
        this
      
      hasAuthorizer: (id) ->
        @authorizers.indexOf(id) >= 0
    
      class Channel
        constructor: (@name) ->
          @subscribers = []
          @publishers = []
    
        addSubscriber: (id) ->
          @subscribers.push(id)
          this
    
        removeSubscriber: (id) ->
          @subscribers.splice(@subscribers.indexOf(id),1)
          this
        
        hasSubscriber: (id) ->
          @subscribers.indexOf(id) >= 0
    
        addPublisher: (id) ->
          @publishers.push(id)
          this
    
        removePublisher: (id) ->
          @publishers.splice(@publishers.indexOf(id),1)
          this
        
        hasPublisher: (id) ->
          @publishers.indexOf(id) >= 0
      
    
  constructor: (app, secure) ->
    super(app, secure)
    @hosts = []
    
    @server = new Server()
    @server.addNetwork(app)

  # Override
  connect: ->
    # skip if we are connected
    if @state == "CONNECTED"
      return

    # do a host lookup
    @dispatch("hostlookup")

    @dispatch("connecting")
    @socket = {}
    @socket.onclose = => @disconnected()
    @socket.onmessage = (e) => @process(e)
    @socket.onopen = => @connected()
    @socket.send = (frame) =>
      console.log("-------SEND-------")
      _frame = @decode(frame)
      console.log("frame:",frame)

      response = {
        opcode: ERROR
        _opcode: ""
        channel: _frame.channel
        data: ""
      }
      
      console.log(@server)
      
      switch _frame.opcode
        when SUBSCRIBE
          console.log("SUBSCRIBE")
          if @server.networks[@app].clients.indexOf(@clientId) >= 0
            unless @server.networks[@app].channels[_frame.channel]
              @server.networks[@app].addChannel(_frame.channel)
            @server.networks[@app].channels[_frame.channel].addSubscriber(@clientId)
            response.opcode = SUBSCRIBE_COMPLETE
          else
            response.opcode = SUBSCRIBE_DENIED
        when UNSUBSCRIBE
          console.log("UNSUBSCRIBE")
          @server.networks[@app].channels[_frame].removeSubscriber(@clientId)
          response.opcode = UNSUBSCRIBE_COMPLETE
        when PUBLISH
          console.log("PUBLISH")
          if ! @server.networks[@app].hasChannel(_frame.channel)
            response.opcode = ERROR
            response.data = "channel '" + _frame.channel + "' does not exist on the network '" + @app + "'"
          else if !@server.networks[@app].channels[_frame.channel].hasPublisher(@clientId)
            response.opcode = PUBLISH_DENIED
            response.data = "client does not have publish priviledges on channel '" + _frame.channel + "'"
          else
            response = _frame
          
        when AUTHORIZE
          console.log("AUTHORIZE")
          response.opcode = AUTHORIZE_COMPLETE

      response._opcode = response.opcode.toString(16)
      console.log("response:",response._opcode,response)
      @dispatch("message",response)
      this

    @forcedc = false
    
    @clientId = @server.addClient()
    @server.networks[@app].addClient(@clientId)
    @socket.onopen()
    @dispatch("message",{opcode:CONNECT_COMPLETE,channel:"",data:@clientId})
    this

  # Override
  disconnect: ->
    @forcedc = true
    @disconnected

  # Override
  transmit: (frame) ->
    @socket.send(frame)


