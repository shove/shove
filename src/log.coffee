# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License

class Log
  constructor: () ->
    @callback = false

  debug: (type, message) ->
    if @callback
      if message.length == 0
        @callback.apply(window, [{ event: type }])
      else
        @callback.apply(window, message)

      

log = new Log