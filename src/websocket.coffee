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
        this.proxy = document.getElementById("wsproxy")
        while this.queue.length > 0
          this.queue.shift.call(this)
        this
      
      onload: (msg) ->
        if console && console.log
           console.log(msg)
        this
      
      register: (socket) ->
        if this.proxy == null
          this.queue.push(() => this.register(socket))         
        else
          this.socket = socket;
          this.proxy.open(socket.uri)
        this

      send: (data) ->
        if this.proxy == null
          this.queue.push(() => this.send(data))
        else
          this.proxy.send(data)
        this

      onopen: ->
        this.socket.onopen({})
        this

      onmessage: (data) ->
        this.socket.onmessage({data:data})
        this

      onclose: ->
        this.socket.onclose({})
        this
 
    class WebSocket
      constructor: (@uri) ->
        WebSocketProxy.register(this)
  
      send: (data) -> WebSocketProxy.send(data)

    swfobject.embedSWF("http://static-dev.shove.io/a01/proxy.swf", "wsproxy", "1", "1", "9.0.0", "", {  
    },{
      allowscriptaccess: "always",
      allownetworking: "all"
    })

)()
