(function() {
  var Transport, WebSocketTransport, head, injectScript, removeScript, transportEvents,
    __slice = Array.prototype.slice,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  transportEvents = ["connect", "connecting", "disconnect", "message", "reconnect", "error", "statechange", "hostlookup"];

  head = document.getElementsByTagName("head")[0];

  injectScript = function(id, url) {
    var script;
    script = document.createElement("script");
    script.setAttribute("src", url);
    script.setAttribute("type", "text/javascript");
    script.setAttribute("id", id);
    return head.appendChild(script);
  };

  removeScript = function(id) {
    return head.removeChild(document.getElementById(id));
  };

  Transport = (function() {

    function Transport(app, secure) {
      this.app = app;
      this.secure = secure;
      this.queue = [];
      this.state = "DISCONNECTED";
      this.callbacks = {};
      this.connections = 0;
      this.forcedc = false;
      this.hosts = ["shove.dev:9000"];
    }

    Transport.prototype.requestHosts = function() {
      return injectScript("hostlookup", "http://shove.dev:8080/apps/" + this.app + "/nodes");
    };

    Transport.prototype.updateHosts = function(hosts) {
      removeScript("hostlookup");
      if (hosts) {
        this.hosts = hosts;
        return this.connect();
      } else {
        return this.dispatch("error", "No hosts found for app " + this.app);
      }
    };

    Transport.prototype.host = function() {
      return this.hosts[this.connections % this.hosts.length];
    };

    Transport.prototype.on = function(event, cb) {
      if (transportEvents.indexOf(event) === -1) {
        return console.error("Unknow event " + event + ".  Valid events: " + (transportEvents.join(", ")));
      } else {
        if (!this.callbacks[event]) this.callbacks[event] = [];
        return this.callbacks[event].push(cb);
      }
    };

    Transport.prototype.connect = function() {
      return console.error("abstract method connect called on transport");
    };

    Transport.prototype.disconnect = function() {
      return console.error("abstract method disconnect called on transport");
    };

    Transport.prototype.send = function(data) {
      if (this.state !== "CONNECTED") {
        this.queue.push(data);
      } else {
        this.transmit(this.encode(data));
      }
      return this;
    };

    Transport.prototype.dispatch = function() {
      var args, callback, event, _i, _len, _ref;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      if (this.callbacks[event]) {
        _ref = this.callbacks[event];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          callback = _ref[_i];
          callback.apply(window, args);
        }
      }
      return this;
    };

    Transport.prototype.process = function(msg) {
      return this.dispatch("message", this.decode(msg.data));
    };

    Transport.prototype.connected = function(e) {
      this.state = "CONNECTED";
      this.connections++;
      if (this.connections > 1) {
        this.dispatch("reconnect");
      } else {
        this.dispatch("connect");
      }
      while (this.queue.length > 0) {
        this.send(this.queue.shift());
      }
      return this;
    };

    Transport.prototype.disconnected = function() {
      var closed,
        _this = this;
      this.state = "DISCONNECTED";
      this.dispatch("disconnect");
      closed = function() {
        return _this.connect();
      };
      if (!this.forcedc) setTimeout(closed, 2000);
      return this;
    };

    Transport.prototype.transmit = function(data) {
      return console.error("Transport does not support sending frames.");
    };

    Transport.prototype.decode = function(msg) {
      return JSON.parse(msg);
    };

    Transport.prototype.encode = function(msg) {
      return JSON.stringify(msg);
    };

    return Transport;

  })();

  WebSocketTransport = (function(_super) {

    __extends(WebSocketTransport, _super);

    function WebSocketTransport(app, secure) {
      WebSocketTransport.__super__.constructor.call(this, app, secure);
    }

    WebSocketTransport.prototype.connect = function() {
      var _this = this;
      if (this.state === "CONNECTED") return;
      if (!this.hosts) {
        this.dispatch("hostlookup");
        this.requestHosts();
        return;
      }
      this.dispatch("connecting");
      this.socket = new WebSocket("" + (this.secure ? "wss" : "ws") + "://" + (this.host()) + "/" + this.app);
      this.socket.onclose = function() {
        return _this.disconnected();
      };
      this.socket.onmessage = function(e) {
        return _this.process(e);
      };
      this.socket.onopen = function() {
        return _this.connected();
      };
      return this.forcedc = false;
    };

    WebSocketTransport.prototype.disconnect = function() {
      this.forcedc = true;
      return this.socket.close();
    };

    WebSocketTransport.prototype.transmit = function(frame) {
      return this.socket.send(frame);
    };

    return WebSocketTransport;

  })(Transport);

}).call(this);
