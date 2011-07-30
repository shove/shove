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
        while this.queue.length > 0
          @queue.shift.call(this)
        this
      
      onload: (msg) ->
        if console && console.log
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

    swfobject.embedSWF("http://static-dev.shove.io/proxy.swf", "wsproxy", "1", "1", "9.0.0", "", {  
    },{
      allowscriptaccess: "always",
      allownetworking: "all"
    })

)()
