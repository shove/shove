




class ShoveMockClient
  constructor: (@id = -1) ->
  
  setId: (id) ->
    @id = id
    this





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
  constructor: (@name,@networkKey = '') ->
    @channels = []
    @clients = []
    @authorizers = []

  addChannel: (name) ->
    channel = new ShoveMockChannel(name)
    @channels.push(channel)
    for a in @authorizers
      channel.addPublisher(a)
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
    channelName = "direct:#{client.id}"
    if ! directChannel = @findChannel(channelName)
      directChannel = @addChannel(channelName)
    directChannel.addSubscriber(client)
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
    for c in @channels
      c.addPublisher(client)
    this

  removeAuthorizer: (client) ->
    @authorizers.splice(@authorizers.indexOf(client),1)
    for c in @channels
      c.removePublisher(client)

  hasAuthorizer: (client) ->
    @authorizers.indexOf(client) >= 0
  
  checkNetworkKey: (key) ->
    # return @networkKey === key
    return !! key.length



class ShoveMockServer
  constructor: () ->
    @networks = []
    @clients = []
    
    @effectiveNetwork = null
    @effectiveClient = @addClient()

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
  
  setEffectiveNetwork: (@effectiveNetwork) ->
    null

  addClient: (id = @generateClientId()) ->
    client = new ShoveMockClient(id)
    @clients.push(client)
    client

  generateClientId: () ->
    if !@generateClientId.i
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
  
  process: (msg = "{}") ->
    frame = JSON.parse(msg)


    if ! 'opcode' in frame
      frame.opcode = 0
    
    response = {
      opcode: ERROR
      data: ""
    }

    switch frame.opcode
      
      when CONNECT
        if 'data' in frame and frame.data.length > 0
          @effectiveClient.setId(frame.data)
        response.opcode = CONNECT_GRANTED
        response.data = @effectiveClient.id
      
      when SUBSCRIBE
        if frame.channel.indexOf("private:") >= 0
          response.channel = frame.channel
          response.opcode = SUBSCRIBE_DENIED
        else
          chan = @effectiveNetwork.findChannel(frame.channel)
          if ! chan
            chan = @effectiveNetwork.addChannel(frame.channel)
          chan.addSubscriber(@effectiveClient)
          response.channel = chan.name
          response.opcode = SUBSCRIBE_GRANTED
      
      when UNSUBSCRIBE
        chan = @effectiveNetwork.findChannel(frame.channel)
        if ! chan
          response.data = "channel does not exist on the connected network"
        else if ! chan.hasSubscriber(@effectiveClient)
          response.data = "you weren't subscribed to the channel in the first place"
        else
          chan.removeSubscriber(@effectiveClient)
          response.channel = chan.name
          response.opcode = UNSUBSCRIBE_COMPLETE
      
      when PUBLISH
        chan = @effectiveNetwork.findChannel(frame.channel)
        if ! chan
          response.data = "channel does not exist on the connected network"
        else if ! chan.hasPublisher(@effectiveClient)
          response.opcode = PUBLISH_DENIED
          response.data = "you do not have publishing priviledges on this channel"
        else if ! chan.hasSubscriber(@effectiveClient)
          return null
        else
          response = frame

      when AUTHORIZE
        if @effectiveNetwork.checkNetworkKey(frame.data)
          response.opcode = AUTHORIZE_GRANTED
          @effectiveNetwork.addAuthorizer(@effectiveClient)
        else
          response.opcode = AUTHORIZE_DENIED
      
      when ERROR
        response.data = "why you error dog?"

    _opcode = response.opcode.toString(16)
    return JSON.stringify(response)


  




class MockSocket

  constructor: (@url,@protocols...) ->
    @extensions = ""
    @protocol = ""
    @readyState = @state('connecting')
    @bufferedAmount = 0
    
    urlReg = /^([\w\d]+):\/\/([^\/]+)\/([^\/]+)(.*?)$/gi
    urlMatches = urlReg.exec(@url)
    
    @app = urlMatches[3]

    # Seed ShoveMockServer
    @server = new ShoveMockServer()
    network = @server.addNetwork(@app)
    @server.setEffectiveNetwork(network)
    
    this

  close: (code = 0,reason = "") ->
    @readyState = @state('closing')
    @onclose()
    null
  
  state: (str) ->
    switch str
      when 'connecting' then return 0
      when 'open' then return 1
      when 'closing' then return 2
      when 'closed' then return 3
    return null


  onopen: () ->
    
  onerror: () ->
    
  onclose: () ->
    
  onmessage: () ->
    
  send: (msg ="{}") ->
    if @readyState == @state('open')
      response = @server.process(msg)
      if response != null
        window.setTimeout((() => @onmessage(response)),10)
      return this
    
    frame = JSON.parse(msg)
    
    if frame.opcode
      if frame.opcode == CONNECT
        connect_response = JSON.parse(@server.process(msg))
        if connect_response.opcode == CONNECT_GRANTED
          @readyState = @state('open')
          @onopen()

    null