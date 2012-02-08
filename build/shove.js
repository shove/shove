(function() {
  var ALLOW_CONNECT, ALLOW_LOG, ALLOW_PUBLISH, ALLOW_SUBSCRIBE, AUTHORIZE, AUTHORIZE_COMPLETE, AUTHORIZE_DENIED, CONNECT_COMPLETE, CONNECT_DENIED, Channel, Client, DENY_CONNECT, DENY_LOG, DENY_PUBLISH, DENY_SUBSCRIBE, ERROR, LOG, LOG_DENIED, LOG_STARTED, MockSocket, MockTransport, PRESENCE_LIST, PRESENCE_SUBSCRIBED, PRESENCE_UNSUBSCRIBED, PUBLISH, PUBLISH_COMPLETE, PUBLISH_DENIED, SUBSCRIBE, SUBSCRIBE_COMPLETE, SUBSCRIBE_DENIED, ShoveMockChannel, ShoveMockClient, ShoveMockNetwork, ShoveMockServer, Transport, UNSUBSCRIBE, UNSUBSCRIBE_COMPLETE, WebSocketTransport, head, injectScript, removeScript, transportEvents,
    __slice = Array.prototype.slice,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; },
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

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
        return console.error("Unknown event " + event + ".  Valid events: " + (transportEvents.join(", ")));
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

  Channel = (function() {

    function Channel(name, transport) {
      this.name = name;
      this.transport = transport;
      this.events = {
        "message": []
      };
      this.filters = [];
      this.state = "unsubscribed";
    }

    Channel.prototype.transition = function(state) {
      this.state = state;
      return this.process(state);
    };

    Channel.prototype.on = function(event, cb) {
      if (!this.events[event]) this.events[event] = [];
      this.events[event].push(cb);
      return this;
    };

    Channel.prototype.process = function(message, user) {
      var e, filter, sub, subs, _i, _j, _k, _len, _len2, _len3, _ref, _ref2;
      e = {
        data: message,
        user: user
      };
      if (this.filters.length > 0) {
        _ref = this.filters;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          filter = _ref[_i];
          e = filter(e);
          if (e === false) return this;
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

    Channel.prototype.publish = function(message) {
      return this.transport.send({
        opcode: PUBLISH,
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

  ERROR = 0xFF;

  CONNECT_COMPLETE = 0x00;

  CONNECT_DENIED = 0x01;

  SUBSCRIBE = 0x10;

  SUBSCRIBE_COMPLETE = 0x11;

  SUBSCRIBE_DENIED = 0x12;

  UNSUBSCRIBE = 0x13;

  UNSUBSCRIBE_COMPLETE = 0x14;

  PUBLISH = 0x20;

  PUBLISH_DENIED = 0x21;

  PUBLISH_COMPLETE = 0x22;

  ALLOW_PUBLISH = 0x30;

  ALLOW_SUBSCRIBE = 0x31;

  ALLOW_CONNECT = 0x32;

  ALLOW_LOG = 0x33;

  DENY_PUBLISH = 0x40;

  DENY_SUBSCRIBE = 0x41;

  DENY_CONNECT = 0x42;

  DENY_LOG = 0x42;

  LOG = 0x50;

  LOG_STARTED = 0x51;

  LOG_DENIED = 0x52;

  AUTHORIZE = 0x60;

  AUTHORIZE_COMPLETE = 0x61;

  AUTHORIZE_DENIED = 0x62;

  PRESENCE_SUBSCRIBED = 0x70;

  PRESENCE_UNSUBSCRIBED = 0x71;

  PRESENCE_LIST = 0x72;

  Client = (function() {

    function Client() {
      this.id = null;
      this.url = null;
      this.app = null;
      this.secure = false;
      this.socket = null;
      this.listeners = {};
      this.channels = {};
      this.authorized = false;
    }

    Client.prototype.connect = function(app, opts) {
      var key, val,
        _this = this;
      if (opts != null) {
        for (key in opts) {
          if (!__hasProp.call(opts, key)) continue;
          val = opts[key];
          this[key] = val;
        }
      }
      this.app = app;
      if (!(this.socket && this.socket.state === "CONNECTED")) {
        if (window.WebSocket !== void 0) {
          this.socket = new MockTransport(this.app, this.secure);
          this.socket.on("message", function() {
            return _this.process.apply(_this, arguments);
          });
          this.socket.on("connect", function() {
            return _this.trigger("connect");
          });
          this.socket.on("connecting", function() {
            return _this.trigger("connecting");
          });
          this.socket.on("disconnect", function() {
            return _this.trigger("disconnect");
          });
          this.socket.on("reconnect", function() {
            return _this.onReconnect();
          });
          this.socket.connect();
        }
        return this;
      }
    };

    Client.prototype.disconnect = function() {
      this.socket.disconnect();
      return this;
    };

    Client.prototype.channel = function(name) {
      if (!this.channels[name]) {
        this.channels[name] = new Channel(name, this.socket);
      }
      return this.channels[name];
    };

    Client.prototype.on = function(event, cb) {
      if (!this.listeners[event]) this.listeners[event] = [];
      this.listeners[event].push(cb);
      return this;
    };

    Client.prototype.identity = function() {
      return this.id;
    };

    Client.prototype.publish = function(channel, message) {
      this.socket.send({
        opcode: PUBLISH,
        channel: channel,
        data: message
      });
      return this;
    };

    Client.prototype.authorize = function(key) {
      this.socket.send({
        opcode: AUTHORIZE,
        channel: "*",
        data: key
      });
      return this;
    };

    Client.prototype.setHosts = function(hosts) {
      return this.socket.updateHosts(hosts);
    };

    Client.prototype.process = function(e) {
      var chan;
      chan = this.channels[e.channel];
      switch (e.opcode) {
        case CONNECT_COMPLETE:
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
        case PUBLISH:
          chan.process(e.data);
          break;
        case AUTHORIZE_COMPLETE:
          this.authorized = true;
          break;
        case ERROR:
          console.log(e.data);
          break;
        default:
          return;
      }
      return this.trigger(e.event, e.data);
    };

    Client.prototype.trigger = function() {
      var args, callback, event, _i, _len, _ref;
      event = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      if (this.listeners[event]) {
        _ref = this.listeners[event];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          callback = _ref[_i];
          callback.apply(window, args);
        }
      }
      return this;
    };

    Client.prototype.onReconnect = function() {
      var channel, name, _ref;
      _ref = this.channels;
      for (name in _ref) {
        channel = _ref[name];
        channel.subscribe();
      }
      return this.trigger("reconnect");
    };

    return Client;

  })();

  window.$shove = new Client();

  if (window.jQuery) {
    $(function() {
      return $.shove = window.$shove;
    });
  }

  (function() {
    if (!(window.console && window.console.log)) {
      return window.console = {
        log: function() {},
        error: function() {}
      };
    }
  })();

  ShoveMockClient = (function() {

    function ShoveMockClient(id) {
      this.id = id != null ? id : -1;
    }

    return ShoveMockClient;

  })();

  ShoveMockChannel = (function() {

    function ShoveMockChannel(name) {
      this.name = name;
      this.subscribers = [];
      this.publishers = [];
    }

    ShoveMockChannel.prototype.addSubscriber = function(client) {
      this.subscribers.push(client);
      return this;
    };

    ShoveMockChannel.prototype.removeSubscriber = function(client) {
      return this.subscribers.splice(this.subscribers.indexOf(client), 1);
    };

    ShoveMockChannel.prototype.hasSubscriber = function(client) {
      return this.subscribers.indexOf(client) >= 0;
    };

    ShoveMockChannel.prototype.addPublisher = function(client) {
      this.publishers.push(client);
      return this;
    };

    ShoveMockChannel.prototype.removePublisher = function(client) {
      return this.publishers.splice(this.publishers.indexOf(client), 1);
    };

    ShoveMockChannel.prototype.hasPublisher = function(client) {
      return this.publishers.indexOf(client) >= 0;
    };

    return ShoveMockChannel;

  })();

  ShoveMockNetwork = (function() {

    function ShoveMockNetwork(name) {
      this.name = name;
      this.channels = [];
      this.clients = [];
      this.authorizers = [];
    }

    ShoveMockNetwork.prototype.addChannel = function(name) {
      var channel;
      channel = new ShoveMockChannel(name);
      this.channels.push(channel);
      return channel;
    };

    ShoveMockNetwork.prototype.removeChannel = function(channel) {
      return this.channels.splice(this.channels.indexOf(channel), 1);
    };

    ShoveMockNetwork.prototype.hasChannel = function(channel) {
      return this.channels.indexOf(channel) >= 0;
    };

    ShoveMockNetwork.prototype.findChannel = function(name) {
      var channel, _i, _len, _ref;
      _ref = this.channels;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        channel = _ref[_i];
        if (channel.name === name) return channel;
      }
      return null;
    };

    ShoveMockNetwork.prototype.addClient = function(client) {
      this.clients.push(client);
      return this;
    };

    ShoveMockNetwork.prototype.removeClient = function(client) {
      this.removeAuthorizer(client);
      return this.clients.splice(this.clients.indexOf(client), 1);
    };

    ShoveMockNetwork.prototype.hasClient = function(client) {
      return this.clients.indexOf(client) >= 0;
    };

    ShoveMockNetwork.prototype.addAuthorizer = function(client) {
      if (!this.hasClient(client)) this.addClient(client);
      this.authorizers.push(client);
      return this;
    };

    ShoveMockNetwork.prototype.removeAuthorizer = function(client) {
      return this.authorizers.splice(this.authorizers.indexOf(client), 1);
    };

    ShoveMockNetwork.prototype.hasAuthorizer = function(client) {
      return this.authorizers.indexOf(client) >= 0;
    };

    return ShoveMockNetwork;

  })();

  ShoveMockServer = (function() {

    function ShoveMockServer() {
      this.networks = [];
      this.clients = [];
    }

    ShoveMockServer.prototype.addNetwork = function(name) {
      return this.networks.push(new ShoveMockNetwork(name));
    };

    ShoveMockServer.prototype.removeNetwork = function(network) {
      return this.networks.splice(this.networks.indexOf(network), 1);
    };

    ShoveMockServer.prototype.hasNetwork = function(network) {
      return this.networks.indexOf(network) >= 0;
    };

    ShoveMockServer.prototype.findNetwork = function(name) {
      var network, _i, _len, _ref;
      _ref = this.networks;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        network = _ref[_i];
        if (network.name === name) return network;
      }
      return null;
    };

    ShoveMockServer.prototype.addClient = function(id) {
      var client;
      if (id == null) id = this.generateClientId();
      client = new ShoveMockClient(id);
      this.clients.push(client);
      return client;
    };

    ShoveMockServer.prototype.generateClientId = function() {
      var _ref;
      if (_ref = !i, __indexOf.call(this.generateClientId, _ref) >= 0) {
        this.generateClientId.i = 0;
      }
      return "client" + this.generateClientId.i++;
    };

    ShoveMockServer.prototype.removeClient = function(client) {
      return this.clients.splice(this.clients.indexOf(client), 1);
    };

    ShoveMockServer.prototype.hasClient = function(client) {
      return this.clients.indexOf(client) >= 0;
    };

    ShoveMockServer.prototype.findClient = function(id) {
      var client, _i, _len, _ref;
      _ref = this.clients;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        client = _ref[_i];
        if (client.id === id) return client;
      }
      return null;
    };

    return ShoveMockServer;

  })();

  MockSocket = (function() {

    MockSocket.CONNECTING = 0;

    MockSocket.OPEN = 1;

    MockSocket.CLOSING = 2;

    MockSocket.CLOSED = 3;

    function MockSocket() {
      var protocols, url;
      url = arguments[0], protocols = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      this.url = url;
      this.protocols = protocols;
      this.extensions = "";
      this.protocol = "";
      this.readyState = MockSocket.CONNECTING;
      this.bufferedAmount = 0;
      this.onopen();
      this.server = new ShoveMockServer();
      this.network = this.server.addNetwork(app);
      this;
    }

    MockSocket.prototype.close = function(code, reason) {
      if (code == null) code = 0;
      if (reason == null) reason = "";
      this.readyState = MockSocket.CLOSED;
      return this.onclose();
    };

    MockSocket.prototype.onopen = function() {};

    MockSocket.prototype.onerror = function() {};

    MockSocket.prototype.onclose = function() {};

    MockSocket.prototype.onmessage = function() {};

    MockSocket.prototype.send = function(msg) {
      var channel, frame, response;
      frame = JSON.parse(msg);
      channel = this.network.findChannel(frame.channel);
      console.log("-------SEND-------");
      console.log("frame:", frame);
      console.log(this.server);
      console.log(this.server.hasClient(this.client));
      console.log(this.network.hasClient(this.client));
      response = {
        opcode: ERROR,
        _opcode: "",
        channel: frame.channel,
        data: ""
      };
      switch (frame.opcode) {
        case SUBSCRIBE:
          console.log("SUBSCRIBE");
          if (!this.network.hasChannel(channel)) {
            response.opcode = SUBSCRIBE_DENIED;
            response.data = "channel does not exist on the connected network";
          } else {
            channel.addSubscriber(this.client);
            response.opcode = SUBSCRIBE_COMPLETE;
          }
          break;
        case UNSUBSCRIBE:
          console.log("UNSUBSCRIBE");
          if (!this.network.hasChannel(channel)) {
            response.data = "channel does not exist on the connected network";
          } else if (!this.channel.hasSubscriber(this.client)) {
            response.data = "you weren't subscribed to the channel in the first place";
          } else {
            channel.removeSubscriber(this.client);
            response.opcode = UNSUBSCRIBE_COMPLETE;
          }
          break;
        case PUBLISH:
          console.log("PUBLISH");
          if (!this.network.hasChannel(channel)) {
            response.data = "channel does not exist on the connected network";
          } else if (!channel.hasPublisher(this.clientId)) {
            response.opcode = PUBLISH_DENIED;
            response.data = "you do not have publishing priviledges on this channel";
          } else {
            response = frame;
          }
          break;
        case AUTHORIZE:
          console.log("AUTHORIZE");
          response.opcode = AUTHORIZE_COMPLETE;
      }
      response._opcode = response.opcode.toString(16);
      console.log("response:", response._opcode, response);
      this.onmessage(JSON.stringify(response));
      return null;
    };

    return MockSocket;

  })();

  MockTransport = (function(_super) {

    __extends(MockTransport, _super);

    function MockTransport(app, secure) {
      MockTransport.__super__.constructor.call(this, app, secure);
    }

    MockTransport.prototype.connect = function() {
      var _this = this;
      if (this.state === "CONNECTED") return;
      this.dispatch("hostlookup");
      this.dispatch("connecting");
      this.socket = new MockSocket();
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

    MockTransport.prototype.disconnect = function() {
      this.forcedc = true;
      return this.socket.close();
    };

    MockTransport.prototype.transmit = function(frame) {
      return this.socket.send(frame);
    };

    return MockTransport;

  })(Transport);

}).call(this);
