###
Copyright (C) 2011 by Dan Simpson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

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
  
  ###
  Connect to a network
  @param {String} network The name of the network
  @return {Shove} The global Shove object
  ###
  connect: (network) ->
    @network = network
    unless @transport && @transport.connected
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
       
  ###
  Disconnect from current network
  @return {Shove} The global Shove object
  ###
  disconnect: ->
    @transport.disconnect()
    this

  ###
  Return a channel object for a given network
  and subscribe to it on the remote host if not
  currently subscribed
  @param {String} name The name of the channel
  @return {Channel} The channel object
  ###
  channel: (name) ->
    unless @channels[name]
      @channels[name] = new Channel(name, @transport)
    @channels[name]

  ###
  Add a network event listener
  @param {String} event The name of the event
  @param {Function} cb The callback function to call
  when the event arises
  @return {Shove} The global Shove object
  ###
  on: (event, cb) ->
    unless @events[event]
      @events[event] = []
    @events[event].push(cb)
    this

  ###
  @return The identity of the browser which
  is unique to the shove network.
  ###
  identity: ->
    @id

  ###
  Toggle debugging
  @param {Boolean} option true or false
  @return {Shove} The global Shove object
  ###
  debug: (option) ->
    @debugMode = option || true
    this

  ###
  Send a message directly to another on the network
  @param {Boolean} option true or false
  @return {Shove} The global Shove object
  ###
  direct: (client, event, message) ->
    @transport.send({
      event: event,
      to: client,
      data: message
    })
    this

  ###
  Process a shove message
  ###
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

  ###
  Dispatch event to listeners
  ###
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
