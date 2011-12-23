(function() {
  var CONNECT_DENIED, CONNECT_PERMITTED, Channel, Client, CometTransport, DEBUG, DEBUG_DENIED, DEBUG_PERMITTED, DIRECT, DIRECT_DENIED, DIRECT_PERMITTED, ERROR, Log, PERMIT_ADMIN, PERMIT_CONNECT, PERMIT_DEBUG, PERMIT_PUBLISH, PERMIT_SUBSCRIBE, PRESENCE_LIST, PRESENCE_SUBSCRIBE, PRESENCE_UNSUBSCRIBE, PUBLISH, PUBLISH_DENIED, PUBLISH_PERMITTED, SET_IDENTITY, SUBSCRIBE, SUBSCRIBE_COMPLETE, SUBSCRIBE_DENIED, Transport, UNSUBSCRIBE, UNSUBSCRIBE_COMPLETE, WebSocketTransport, head, injectScript, log, removeScript, transportEvents;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  Log = (function() {
    function Log() {
      this.callback = false;
    }
    Log.prototype.debug = function(type, message) {
      if (this.callback) {
        if (message.length === 0) {
          return this.callback.apply(window, [
            {
              event: type
            }
          ]);
        } else {
          return this.callback.apply(window, message);
        }
      }
    };
    return Log;
  })();
  log = new Log;
  (function() {
    var WebSocket, WebSocketProxy, attrs, err;
    if (!window.WebSocket) {
      if (window.MozWebSocket) {
        window.WebSocket = window.MozWebSocket;
        return;
      }
      if (!swfobject.hasFlashPlayerVersion("9.0.0")) {
        console.error("Flash Player >= 9.0.0 is required.");
        return;
      }
      document.write("<div id=\"wsproxy\">Loading</div>");
      if (location.protocol === "file:") {
        err = "NOTICE: shove flash fallback does NOT work in file:///... URL      unless you set Flash Security Settings properly.        Open the page via Web server i.e. http://...";
        console.error(err);
      }
      WebSocketProxy = {
        queue: [],
        proxy: null,
        socket: null,
        ready: function() {
          this.proxy = document.getElementById("wsproxy");
          return this.flush();
        },
        flush: function() {
          while (this.queue.length > 0) {
            this.queue.shift().call(this);
          }
          return this;
        },
        onlog: function(msg) {
          if (window.console && console.log) {
            console.log(msg);
          }
          return this;
        },
        register: function(socket) {
          if (this.proxy === null) {
            this.queue.push(__bind(function() {
              return this.register(socket);
            }, this));
          } else {
            this.socket = socket;
            this.proxy.open(socket.uri);
          }
          return this;
        },
        send: function(data) {
          if (this.proxy === null) {
            this.queue.push(__bind(function() {
              return this.send(data);
            }, this));
          } else {
            this.proxy.send(data);
          }
          return this;
        },
        close: function() {
          this.proxy.close();
          return this;
        },
        onopen: function() {
          this.socket.onopen({});
          return this;
        },
        onmessage: function(data) {
          this.socket.onmessage({
            data: data
          });
          return this;
        },
        onclose: function() {
          this.socket.onclose({});
          return this;
        }
      };
      WebSocket = (function() {
        function WebSocket(uri) {
          this.uri = uri;
          WebSocketProxy.register(this);
        }
        WebSocket.prototype.send = function(data) {
          return WebSocketProxy.send(data);
        };
        WebSocket.prototype.close = function() {
          return WebSocketProxy.close();
        };
        WebSocket.prototype.onmessage = function(e) {};
        WebSocket.prototype.onclose = function(e) {};
        WebSocket.prototype.onopen = function(e) {};
        return WebSocket;
      })();
      window.WebSocketProxy = WebSocketProxy;
      window.WebSocket = WebSocket;
      attrs = {
        allowscriptaccess: "always",
        allowapping: "all"
      };
      return swfobject.embedSWF("http://static-dev.shove.io:8000/proxy.swf", "wsproxy", "1", "1", "9.0.0", "", {}, attrs);
    }
  })();
  transportEvents = ["connect", "connecting", "disconnect", "message", "reconnect", "reconnect", "error", "statechange", "hostlookup"];
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
      this.hosts = null;
    }
    Transport.prototype.requestHosts = function() {
      return injectScript("hostlookup", "http://api-dev.shove.io:4000/apps/" + this.app + "/nodes");
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
        if (!this.callbacks[event]) {
          this.callbacks[event] = [];
        }
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
      log.debug(event, args);
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
      var closed;
      this.state = "DISCONNECTED";
      this.dispatch("disconnect");
      closed = __bind(function() {
        return this.connect();
      }, this);
      if (!this.forcedc) {
        setTimeout(closed, 2000);
      }
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
  WebSocketTransport = (function() {
    __extends(WebSocketTransport, Transport);
    function WebSocketTransport(app, secure) {
      WebSocketTransport.__super__.constructor.call(this, app, secure);
    }
    WebSocketTransport.prototype.connect = function() {
      if (this.state === "CONNECTED") {
        return;
      }
      if (!this.hosts) {
        this.dispatch("hostlookup");
        this.requestHosts();
        return;
      }
      this.dispatch("connecting");
      this.socket = new WebSocket("" + (this.secure ? "wss" : "ws") + "://" + (this.host()) + ".shove.io/" + this.app);
      this.socket.onclose = __bind(function() {
        return this.disconnected();
      }, this);
      this.socket.onmessage = __bind(function(e) {
        return this.process(e);
      }, this);
      this.socket.onopen = __bind(function() {
        return this.connected();
      }, this);
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
  })();
  CometTransport = (function() {
    __extends(CometTransport, Transport);
    function CometTransport(app, secure) {
      CometTransport.__super__.constructor.call(this, app, secure);
      this.seed = 1;
      this.started = null;
      this.requesting = false;
      this.timeout = 10000;
      this.timer = null;
      window["_scb"] = __bind(function(event) {
        return this.onLoad(event);
      }, this);
    }
    CometTransport.prototype.connect = function() {
      this.url = "" + (this.secure ? "https" : "http") + "://poll-" + (this.host()) + ".shove.io/" + this.app;
      return this.request();
    };
    CometTransport.prototype.request = function(data) {
      clearTimeout(this.timer);
      this.timer = setTimeout((__bind(function() {
        return this.onTimeout();
      }, this)), this.timeout);
      return this.addTag(this.getUrl());
    };
    CometTransport.prototype.addTag = function(url) {
      return injectScript("comet" + this.seed, url);
    };
    CometTransport.prototype.removeTag = function() {
      return removeScript("comet" + (this.seed++));
    };
    CometTransport.prototype.getUrl = function() {
      var suffix;
      suffix = "/" + Math.random();
      if (this.queue.length > 0) {
        suffix += "/" + this.queue.shift();
      }
      return "" + this.url + suffix;
    };
    CometTransport.prototype.onLoad = function(data) {
      if (data === "connect") {
        this.connected();
      } else {
        this.process({
          data: data
        });
      }
      clearTimeout(this.timer);
      return this.timer = setTimeout((__bind(function() {
        return this.request();
      }, this)), 20);
    };
    CometTransport.prototype.onTimeout = function() {
      this.removeTag();
      return this.request();
    };
    CometTransport.prototype.transmit = function(message) {
      this.removeTag();
      return this.request(message);
    };
    return CometTransport;
  })();
  Channel = (function() {
    function Channel(name, transport) {
      this.name = name;
      this.transport = transport;
      this.events = {
        "*": []
      };
      this.filters = [];
      this.state = "unsubscribed";
      this.subscribe();
    }
    Channel.prototype.transition = function(state) {
      this.state = state;
      return this.process(state);
    };
    Channel.prototype.on = function(event, cb) {
      if (!this.events[event]) {
        this.events[event] = [];
      }
      this.events[event].push(cb);
      return this;
    };
    Channel.prototype.process = function(event, message, user) {
      var e, filter, sub, subs, _i, _j, _k, _len, _len2, _len3, _ref, _ref2;
      e = {
        event: event,
        data: message,
        user: user
      };
      if (this.filters.length > 0) {
        _ref = this.filters;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          filter = _ref[_i];
          e = filter(e);
          if (e === false) {
            return this;
          }
        }
      }
      if (event !== "*") {
        subs = this.events[event];
        if (subs) {
          for (_j = 0, _len2 = subs.length; _j < _len2; _j++) {
            sub = subs[_j];
            sub(e);
          }
        }
      }
      _ref2 = this.events["*"];
      for (_k = 0, _len3 = _ref2.length; _k < _len3; _k++) {
        sub = _ref2[_k];
        sub(e);
      }
      return this;
    };
    Channel.prototype.publish = function(event, message) {
      return this.transport.send({
        opcode: PUBLISH,
        event: event,
        channel: this.name,
        data: message
      });
    };
    Channel.prototype.unsubscribe = function() {
      return this.transport.send({
        opcode: UNSUBSCRIBE,
        channel: this.name
      });
    };
    Channel.prototype.subscribe = function() {
      return this.transport.send({
        opcode: SUBSCRIBE,
        channel: this.name
      });
    };
    Channel.prototype.filter = function(fn) {
      this.filters.push(fn);
      return this;
    };
    return Channel;
  })();
  ERROR = 0;
  DEBUG = 1;
  PERMIT_CONNECT = 2;
  PERMIT_DEBUG = 3;
  PUBLISH = 21;
  PUBLISH_PERMITTED = 22;
  SUBSCRIBE = 23;
  UNSUBSCRIBE = 24;
  PERMIT_PUBLISH = 25;
  PERMIT_SUBSCRIBE = 26;
  PRESENCE_SUBSCRIBE = 27;
  PRESENCE_UNSUBSCRIBE = 28;
  PRESENCE_LIST = 29;
  SET_IDENTITY = 41;
  PUBLISH_DENIED = 42;
  SUBSCRIBE_COMPLETE = 43;
  SUBSCRIBE_DENIED = 44;
  UNSUBSCRIBE_COMPLETE = 45;
  DEBUG_DENIED = 46;
  DEBUG_PERMITTED = 47;
  CONNECT_DENIED = 48;
  CONNECT_PERMITTED = 49;
  DIRECT = 50;
  DIRECT_DENIED = 51;
  DIRECT_PERMITTED = 52;
  PERMIT_ADMIN = 53;
  Client = (function() {
    function Client() {
      this.transport = null;
      this.url = null;
      this.channels = {};
      this.app = null;
      this.events = {};
      this.id = null;
      this.secure = false;
      this.authorized = true;
    }
    Client.prototype.connect = function(app, opts) {
      var key, val;
      if (opts != null) {
        for (key in opts) {
          if (!__hasProp.call(opts, key)) continue;
          val = opts[key];
          this[key] = val;
        }
      }
      this.app = app;
      if (!(this.transport && this.transport.state === "CONNECTED")) {
        if (window.WebSocket === void 0) {
          this.transport = new CometTransport(this.app, this.secure);
        } else {
          this.transport = new WebSocketTransport(this.app, this.secure);
        }
        this.transport.on("message", __bind(function() {
          return this._process.apply(this, arguments);
        }, this));
        this.transport.on("connect", __bind(function() {
          return this._dispatch("connect");
        }, this));
        this.transport.on("connecting", __bind(function() {
          return this._dispatch("connecting");
        }, this));
        this.transport.on("reconnect", __bind(function() {
          return this._reconnect();
        }, this));
        this.transport.on("disconnect", __bind(function() {
          return this._dispatch("disconnect");
        }, this));
        this.transport.connect();
      }
      return this;
    };
    Client.prototype.disconnect = function() {
      this.transport.disconnect();
      return this;
    };
    Client.prototype.channel = function(name) {
      if (!this.channels[name]) {
        this.channels[name] = new Channel(name, this.transport);
      }
      return this.channels[name];
    };
    Client.prototype.on = function(event, cb) {
      if (!this.events[event]) {
        this.events[event] = [];
      }
      this.events[event].push(cb);
      return this;
    };
    Client.prototype.identity = function() {
      return this.id;
    };
    Client.prototype.debug = function(fn) {
      log.callback = fn;
      this.transport.send({
        opcode: DEBUG
      });
      return this;
    };
    Client.prototype.direct = function(client, event, message) {
      this.transport.send({
        event: event,
        to: client,
        data: message
      });
      return this;
    };
    Client.prototype.setPublisherKey = function(key) {
      this.transport.send({
        opcode: PERMIT_ADMIN,
        data: key
      });
      return this;
    };
    Client.prototype.setAvailableNodes = function(nodes) {
      return this.transport.updateHosts(nodes);
    };
    Client.prototype._process = function(e) {
      var chan;
      console.log(e);
      chan = this.channels[e.channel];
      switch (e.opcode) {
        case SET_IDENTITY:
          this.id = e.data;
          break;
        case SUBSCRIBE_COMPLETE:
          chan.transition("subscribed");
          break;
        case UNSUBSCRIBE_COMPLETE:
          chan.transition("unsubscribed");
          break;
        case SUBSCRIBE_DENIED:
          chan.transition("unauthorized");
          break;
        case PRESENCE_SUBSCRIBE:
          chan.process("presence", "subscribe", e.from);
          break;
        case PRESENCE_SUBSCRIBE:
          chan.process("presence", "unsubscribe", e.from);
          break;
        case PUBLISH_PERMITTED:
          this.authorized = true;
          break;
        case PUBLISH:
          chan.process(e.event, e.data, e.from);
          break;
        case ERROR:
          break;
        default:
          return;
      }
      return this._dispatch(e.event, e.data);
    };
    Client.prototype._dispatch = function() {
      var args, callback, event, _i, _len, _ref;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      if (this.events[event]) {
        _ref = this.events[event];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          callback = _ref[_i];
          callback.apply(window, args);
        }
      }
      return this;
    };
    Client.prototype._reconnect = function() {
      var channel, name, _ref;
      _ref = this.channels;
      for (name in _ref) {
        channel = _ref[name];
        channel.subscribe();
      }
      return this._dispatch("reconnect");
    };
    return Client;
  })();
  window.Shove = new Client();
  if (window.jQuery) {
    $(function() {
      return $.shove = window.Shove;
    });
  }
  (function() {
    var console;
    console = window.console;
    if (!(console && console.log && console.error)) {
      return console = {
        log: function() {},
        error: function() {}
      };
    }
  })();
}).call(this);
