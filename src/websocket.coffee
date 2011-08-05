# Copyright (C) 2011 by Dan Simpson
# Usage restrictions provided with the MIT License
# http://en.wikipedia.org/wiki/MIT_License

(() ->
  unless window.WebSocket
    document.write("<div id=\"wsproxy\">Loading</div>")

    unless swfobject.hasFlashPlayerVersion("9.0.0")
      console.error("Flash Player >= 9.0.0 is required.")
      return

    if location.protocol == "file:"
      err = "HEYHEYHEY: shove flash fallback does NOT work in file:///... URL
      unless you set Flash Security Settings properly.  
      Open the page via Web server i.e. http://..."
      console.error(err)
  
    WebSocketProxy =
      queue: []
      proxy: null
      socket: null
    
      ready: ->
        @proxy = document.getElementById("wsproxy")
        while @queue.length > 0
          @queue.shift.call(this)
        this
      
      onlog: (msg) ->
        if window.console && console.log
           console.log(msg)
        this
        
      register: (socket) ->
        if @proxy == null
          @queue.push(() => @register(socket))         
        else
          @socket = socket;
          @proxy.open(socket.uri)
        this

      send: (data) ->
        if @proxy == null
          @queue.push(() => @send(data))
        else
          @proxy.send(data)
        this
      close: ->
        @proxy.close()
        this
        
      onopen: ->
        @socket.onopen({})
        this

      onmessage: (data) ->
        @socket.onmessage({data:data})
        this

      onclose: ->
        @socket.onclose({})
        this
 
    class WebSocket
      constructor: (@uri) ->
        WebSocketProxy.register(this)
  
      send: (data) -> WebSocketProxy.send(data)
      close: () -> WebSocketProxy.close()
      onmessage: (e) ->
      onclose: (e) ->
      onopen: (e) ->

    # Scope is good
    window.WebSocketProxy = WebSocketProxy
    window.WebSocket = WebSocket
    
    attrs =
      allowscriptaccess: "always"
      allownetworking: "all"

    swfobject.embedSWF("http://static-dev.shove.io:8888/lib/proxy.swf", "wsproxy", "1", "1", "9.0.0", "", {}, attrs)

)()
