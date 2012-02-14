# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License

#### Channel

class Channel

  constructor: (@name, @transport) ->
    @events = {
      "message": []
      "subscribing": []
      "subscribe": []
      "unsubscribing": []
      "unsubscribe": []
      "unauthorized": []
    }
    @filters = []
    @state = "unsubscribed"
    
    @on("subscribing",(e) => @state = "subscribing")
    @on("subscribe",(e) => @state = "subscribed")
    @on("unsubscribe",(e) => @state = "unsubscribed")
    @on("unauthorized",(e) => @state = "unauthorized")
    
    this

  # Bind a function to an event
  # The function will be called when
  # any message with event matching event
  # is received
  # `event` the event to trigger on
  # `cb` the callback to execute on trigger
  on: (event, cb) ->
    if ! @events.hasOwnProperty(event)
      console.error("Illegal event '#{event}' defined on shove channel")
    @events[event].push(cb)
    this
  
  trigger: (event,e = {}) ->
    if @events.hasOwnProperty(event)
      for cb in @events[event]
        cb(e)
    this

  
  # Process an event to all bound listeners
  # `message` the data package
  process: (data) ->
    if @filters.length > 0
      for filter in @filters
        data = filter(data)
        if data == false
          return this
    
    @trigger("message",data)
        
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
    null

  # Unsubscribe from this channel
  unsubscribe: ->
    @trigger("unsubscribing")
    @transport.send({
      opcode: UNSUBSCRIBE,
      channel: @name
    })
    null

  # Register this channel with shove
  subscribe: ->
    @trigger("subscribing")
    @transport.send({
      opcode: SUBSCRIBE,
      channel: @name
    })
    null

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

