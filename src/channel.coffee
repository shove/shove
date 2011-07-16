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

class Channel

  constructor: (@name, @transport) ->
    @events = {
      "*": []
    }
    @filters = []
    @subscribe()

  ###
  Bind a function to an event
  The function will be called when
  any message with event matching event
  is received
  ###
  on: (event, cb) ->
    unless @events[event]
      @events[event] = []
    @events[event].push(cb)
    this

  ###
  Process an event to all bound listeners
  ###
  process: (event, message, user) ->
    e = {
      event: event
      data: message
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
    
  ###
  Broadcast an event and message on this
  channel
  ###
  broadcast: (event, message) ->
    @transport.send({
      event: event,
      channel: @name,
      data: message
    })

  ###
  Unregister this channel with shove
  ###
  unsubscribe: ->
    @transport.send({
      event: "$unsubscribe",
      channel: @name
    })

  ###
  Register this channel with shove
  ###
  subscribe: ->
    @transport.send({
      event: "$subscribe",
  		channel: @name
    })

  ###
  Add a message filter.  Message filters are called
  before any events propogate, so that you can apply
  logic to every message on every channel.

  Example:
  Shove.filter(function(e) {
    e.timestamp = new Date();
    if(e.timestamp > END_OF_THE_WORLD) {
      return false;
    }
    return e;
  });

  The above example will append a timestamp to all
  messages and also prevent them from propogating
  by returning false when the END_OF_THE_WORLD date
  has passed

  @param {Function} fn The filter function to call
  @return {Shove} The global Shove object
  ###
  filter: (fn) ->
    @filters.push(fn)
    this

