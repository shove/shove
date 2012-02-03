# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License

#### Channel

class Channel

  constructor: (@name, @transport) ->
    @events = {
      "message": []
    }
    @filters = []
    @state = "unsubscribed"

  # Set the state for the channel
  # `state` the state name
  transition: (state) ->
    @state = state
    @process(state)

  # Bind a function to an event
  # The function will be called when
  # any message with event matching event
  # is received
  # `event` the event to trigger on
  # `cb` the callback to execute on trigger
  on: (event, cb) ->
    unless @events[event]
      @events[event] = []
    @events[event].push(cb)
    this

  
  # Process an event to all bound listeners
  # `event` the event name
  # `message` the data package
  # `user` the user it's from
  process: (message, user) ->
    e = {
      data: message,
      user: user
    }
    
    if @filters.length > 0
      for filter in @filters
        e = filter(e)
        if e == false
          return this

    unless event == "*"
      subs = @events[event]
      if subs
        for sub in subs
          sub(e)

    for sub in @events["*"]
      sub(e)
    
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

  # Unsubscribe from this channel
  unsubscribe: ->
    @transport.send({
      opcode: UNSUBSCRIBE,
      channel: @name
    })

  # Register this channel with shove
  subscribe: ->
    @transport.send({
      opcode: SUBSCRIBE,
      channel: @name
    })

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

