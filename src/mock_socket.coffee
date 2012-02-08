




class ShoveMockClient
  constructor: (@id = -1) ->





class ShoveMockChannel
  constructor: (@name) ->
    @subscribers = []
    @publishers = []

  addSubscriber: (client) ->
    @subscribers.push(client)
    this

  removeSubscriber: (client) ->
    @subscribers.splice(@subscribers.indexOf(client),1)

  hasSubscriber: (client) ->
    @subscribers.indexOf(client) >= 0

  addPublisher: (client) ->
    @publishers.push(client)
    this

  removePublisher: (client) ->
    @publishers.splice(@publishers.indexOf(client),1)

  hasPublisher: (client) ->
    @publishers.indexOf(client) >= 0



class ShoveMockNetwork
  constructor: (@name) ->
    @channels = []
    @clients = []
    @authorizers = []

  addChannel: (name) ->
    channel = new ShoveMockChannel(name)
    @channels.push(channel)
    channel

  removeChannel: (channel) ->
    @channels.splice(@channels.indexOf(channel),1)

  hasChannel: (channel) ->
    @channels.indexOf(channel) >= 0

  findChannel: (name) ->
    for channel in @channels
      if channel.name == name
        return channel
    return null

  addClient: (client) ->
    @clients.push(client)
    this

  removeClient: (client) ->
    @removeAuthorizer(client)
    @clients.splice(@clients.indexOf(client),1)

  hasClient: (client) ->
    @clients.indexOf(client) >= 0

  addAuthorizer: (client) ->
    unless @hasClient(client)
      @addClient(client)
    @authorizers.push(client)
    this

  removeAuthorizer: (client) ->
    @authorizers.splice(@authorizers.indexOf(client),1)

  hasAuthorizer: (client) ->
    @authorizers.indexOf(client) >= 0



class ShoveMockServer
  constructor: () ->
    @networks = []
    @clients = []

  addNetwork: (name) ->
    network = new ShoveMockNetwork(name)
    @networks.push(network)
    network

  removeNetwork: (network) ->
    @networks.splice(@networks.indexOf(network),1)

  hasNetwork: (network) ->
    @networks.indexOf(network) >= 0

  findNetwork: (name) ->
    for network in @networks
      if network.name == name
        return network
    return null

  addClient: (id = @generateClientId()) ->
    client = new ShoveMockClient(id)
    @clients.push(client)
    client

  generateClientId: () ->
    if ! i in @generateClientId
      @generateClientId.i = 0
    return "client" + @generateClientId.i++

  removeClient: (client) ->
    @clients.splice(@clients.indexOf(client),1)

  hasClient: (client) ->
    @clients.indexOf(client) >= 0

  findClient: (id) ->
    for client in @clients
      if client.id == id
        return client
    return null
  
  process: (msg = "{}",options = {network:""}) ->
    frame = JSON.parse(msg)
    network = @findNetwork(options.network)

    if ! network
      return null
    
    if ! 'opcode' in frame
      return null
    
    response = {
      opcode: ERROR
      data: ""
    }

    if frame.opcode != CONNECT
      unless channel in frame
        return null
      channel = network.findChannel(frame.channel)

    console.log("frame:",frame)
    console.log(@)
    console.log(@hasClient(@client))
    console.log(network.hasClient(@client))


    switch frame.opcode
      
      when CONNECT
        console.log("CONNECT")
        @client = @server.addClient(frame.id)
        
        response.opcode = CONNECT_GRANTED
        response.data = @client.id
      
      when SUBSCRIBE
        console.log("SUBSCRIBE")
        if ! @network.hasChannel(channel)
          response.opcode = SUBSCRIBE_DENIED
          response.data = "channel does not exist on the connected network"
        else
          channel.addSubscriber(@client)
          response.opcode = SUBSCRIBE_COMPLETE
      
      when UNSUBSCRIBE
        console.log("UNSUBSCRIBE")
        if ! @network.hasChannel(channel)
          response.data = "channel does not exist on the connected network"
        else if ! @channel.hasSubscriber(@client)
          response.data = "you weren't subscribed to the channel in the first place"
        else
          channel.removeSubscriber(@client)
          response.opcode = UNSUBSCRIBE_COMPLETE
      
      when PUBLISH
        console.log("PUBLISH")
        if ! @network.hasChannel(channel)
          response.data = "channel does not exist on the connected network"
        else if ! channel.hasPublisher(@clientId)
          response.opcode = PUBLISH_DENIED
          response.data = "you do not have publishing priviledges on this channel"
        else
          response = frame

      when AUTHORIZE
        console.log("AUTHORIZE")
        response.opcode = AUTHORIZE_COMPLETE

    _opcode = response.opcode.toString(16)
    console.log("response:",_opcode,response)
    return response


  




class MockSocket
  # @CONNECTING = 0
  # @OPEN = 1
  # @CLOSING = 2
  # @CLOSED = 3
  
  

  constructor: (@url,@protocols...) ->
    @extensions = ""
    @protocol = ""
    # @readyState = MockSocket.CONNECTING
    @readyState = 0;
    @bufferedAmount = 0
    
    urlReg = /^([\w\d]+):\/\/([^\/]+)\/([^\/]+)(.*?)$/gi
    urlMatches = urlReg.exec(@url)
    
    app = urlMatches[3]

    # Fake server responses
    @server = new ShoveMockServer()
    @network = @server.addNetwork(app)
    @onopen()
    this

  close: (code = 0,reason = "") ->
    # @readyState = MockSocket.CLOSED
    @readyState = 3
    @onclose()

  onopen: () ->
    
  onerror: () ->
    
  onclose: () ->
    
  onmessage: () ->
    
  send: (msg) ->
    @onmessage(@server.process(msg,{network:@network.name}))
    this