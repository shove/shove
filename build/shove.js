(function() {
  var AUTHORIZE, AUTHORIZE_DENIED, AUTHORIZE_GRANTED, CONNECT, CONNECT_DENIED, CONNECT_GRANTED, Channel, Client, DENY_CONNECT, DENY_CONTROL, DENY_PUBLISH, DENY_SUBSCRIBE, DISCONNECT, DISCONNECT_COMPLETE, ERROR, GRANT_CONNECT, GRANT_CONTROL, GRANT_PUBLISH, GRANT_SUBSCRIBE, LOG, LOG_DENIED, LOG_STARTED, MockSocket, PRESENCE_LIST, PRESENCE_SUBSCRIBED, PRESENCE_UNSUBSCRIBED, PUBLISH, PUBLISH_DENIED, PUBLISH_GRANTED, SUBSCRIBE, SUBSCRIBE_DENIED, SUBSCRIBE_GRANTED, ShoveMockChannel, ShoveMockClient, ShoveMockNetwork, ShoveMockServer, Transport, UNSUBSCRIBE, UNSUBSCRIBE_COMPLETE, WebSocketTransport, head, injectScript, removeScript, transportEvents,
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
      return this.dispatch("message", this.decode(msg));
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
      var _this = this;
      WebSocketTransport.__super__.constructor.call(this, app, secure);
      this.socket = new MockSocket("" + (this.secure ? "wss" : "ws") + "://" + (this.host()) + "/" + this.app);
      this.socket.onclose = function() {
        return _this.disconnected();
      };
      this.socket.onmessage = function(e) {
        return _this.process(e);
      };
      this.socket.onopen = function() {
        return _this.connected();
      };
    }

    WebSocketTransport.prototype.connect = function(id) {
      if (id == null) id = null;
      if (this.state === "CONNECTED") return;
      if (!this.hosts) {
        this.dispatch("hostlookup");
        this.requestHosts();
        return;
      }
      this.dispatch("connecting");
      this.transmit(JSON.stringify({
        opcode: CONNECT,
        data: id
      }));
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
      var _this = this;
      this.name = name;
      this.transport = transport;
      this.events = {
        "message": [],
        "subscribing": [],
        "subscribe": [],
        "unsubscribing": [],
        "unsubscribe": [],
        "unauthorized": []
      };
      this.filters = [];
      this.state = "unsubscribed";
      this.on("subscribing", function(e) {
        return _this.state = "subscribing";
      });
      this.on("subscribe", function(e) {
        return _this.state = "subscribed";
      });
      this.on("unsubscribe", function(e) {
        return _this.state = "unsubscribed";
      });
      this.on("unauthorized", function(e) {
        return _this.state = "unauthorized";
      });
      this;
    }

    Channel.prototype.on = function(event, cb) {
      if (!this.events.hasOwnProperty(event)) {
        console.error("Illegal event '" + event + "' defined on shove channel");
      }
      this.events[event].push(cb);
      return this;
    };

    Channel.prototype.trigger = function(event, e) {
      var cb, _i, _len, _ref;
      if (e == null) e = {};
      if (this.events.hasOwnProperty(event)) {
        _ref = this.events[event];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          cb = _ref[_i];
          cb(e);
        }
      }
      return this;
    };

    Channel.prototype.process = function(data) {
      var filter, _i, _len, _ref;
      if (this.filters.length > 0) {
        _ref = this.filters;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          filter = _ref[_i];
          data = filter(data);
          if (data === false) return this;
        }
      }
      this.trigger("message", data);
      return this;
    };

    Channel.prototype.publish = function(message) {
      this.transport.send({
        opcode: PUBLISH,
        channel: this.name,
        data: message
      });
      return null;
    };

    Channel.prototype.unsubscribe = function() {
      this.trigger("unsubscribing");
      this.transport.send({
        opcode: UNSUBSCRIBE,
        channel: this.name
      });
      return null;
    };

    Channel.prototype.subscribe = function() {
      this.trigger("subscribing");
      this.transport.send({
        opcode: SUBSCRIBE,
        channel: this.name
      });
      return null;
    };

    Channel.prototype.filter = function(fn) {
      this.filters.push(fn);
      return this;
    };

    return Channel;

  })();

  ERROR = 0x00;

  CONNECT = 0x01;

  CONNECT_GRANTED = 0x02;

  CONNECT_DENIED = 0x03;

  DISCONNECT = 0x04;

  DISCONNECT_COMPLETE = 0x06;

  SUBSCRIBE = 0x10;

  SUBSCRIBE_GRANTED = 0x11;

  SUBSCRIBE_DENIED = 0x12;

  UNSUBSCRIBE = 0x13;

  UNSUBSCRIBE_COMPLETE = 0x14;

  PUBLISH = 0x20;

  PUBLISH_DENIED = 0x21;

  PUBLISH_GRANTED = 0x22;

  GRANT_PUBLISH = 0x30;

  GRANT_SUBSCRIBE = 0x31;

  GRANT_CONNECT = 0x32;

  GRANT_CONTROL = 0x33;

  DENY_PUBLISH = 0x40;

  DENY_SUBSCRIBE = 0x41;

  DENY_CONNECT = 0x42;

  DENY_CONTROL = 0x43;

  LOG = 0x50;

  LOG_STARTED = 0x51;

  LOG_DENIED = 0x52;

  AUTHORIZE = 0x60;

  AUTHORIZE_GRANTED = 0x61;

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
      this.app_key = '';
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
          this.socket = new WebSocketTransport(this.app, this.secure);
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
          this.socket.connect(this.id);
        }
      }
      return this;
    };

    Client.prototype.disconnect = function() {
      this.socket.disconnect();
      return this;
    };

    Client.prototype.channel = function(name) {
      var channel;
      if (!(channel = this.channels[name])) {
        channel = new Channel(name, this.socket);
        channel.subscribe();
        this.channels[name] = channel;
      }
      return channel;
    };

    Client.prototype.on = function(event, cb) {
      if (!this.listeners.hasOwnProperty(event)) this.listeners[event] = [];
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

    Client.prototype.authorize = function() {
      this.socket.send({
        opcode: AUTHORIZE,
        channel: "*",
        data: this.app_key
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
        case CONNECT_GRANTED:
          this.id = e.data;
          this.trigger("connect", e.data);
          break;
        case SUBSCRIBE_GRANTED:
          chan.trigger("subscribe", e.data);
          break;
        case UNSUBSCRIBE_COMPLETE:
          chan.trigger("unsubscribe", e.data);
          break;
        case SUBSCRIBE_DENIED:
          chan.trigger("unauthorized", e.data);
          break;
        case PUBLISH:
          chan.process(e.data);
          break;
        case AUTHORIZE_GRANTED:
          this.authorized = true;
          this.trigger("authorize", e.data);
          break;
        case ERROR:
          console.error(e.data);
          break;
        default:
          return;
      }
      return this;
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

    ShoveMockClient.prototype.setId = function(id) {
      this.id = id;
      return this;
    };

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

    function ShoveMockNetwork(name, networkKey) {
      this.name = name;
      this.networkKey = networkKey != null ? networkKey : '';
      this.channels = [];
      this.clients = [];
      this.authorizers = [];
    }

    ShoveMockNetwork.prototype.addChannel = function(name) {
      var a, channel, _i, _len, _ref;
      channel = new ShoveMockChannel(name);
      this.channels.push(channel);
      _ref = this.authorizers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        a = _ref[_i];
        channel.addPublisher(a);
      }
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
      var channelName, directChannel;
      this.clients.push(client);
      channelName = "direct:" + client.id;
      if (!(directChannel = this.findChannel(channelName))) {
        directChannel = this.addChannel(channelName);
      }
      directChannel.addSubscriber(client);
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
      var c, _i, _len, _ref;
      if (!this.hasClient(client)) this.addClient(client);
      this.authorizers.push(client);
      _ref = this.channels;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        c.addPublisher(client);
      }
      return this;
    };

    ShoveMockNetwork.prototype.removeAuthorizer = function(client) {
      var c, _i, _len, _ref, _results;
      this.authorizers.splice(this.authorizers.indexOf(client), 1);
      _ref = this.channels;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        _results.push(c.removePublisher(client));
      }
      return _results;
    };

    ShoveMockNetwork.prototype.hasAuthorizer = function(client) {
      return this.authorizers.indexOf(client) >= 0;
    };

    ShoveMockNetwork.prototype.checkNetworkKey = function(key) {
      return !!key.length;
    };

    return ShoveMockNetwork;

  })();

  ShoveMockServer = (function() {

    function ShoveMockServer() {
      this.networks = [];
      this.clients = [];
      this.effectiveNetwork = null;
      this.effectiveClient = this.addClient();
    }

    ShoveMockServer.prototype.addNetwork = function(name) {
      var network;
      network = new ShoveMockNetwork(name);
      this.networks.push(network);
      return network;
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

    ShoveMockServer.prototype.setEffectiveNetwork = function(effectiveNetwork) {
      this.effectiveNetwork = effectiveNetwork;
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
      if (!this.generateClientId.i) this.generateClientId.i = 0;
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

    ShoveMockServer.prototype.process = function(msg) {
      var chan, frame, response, _opcode, _ref;
      if (msg == null) msg = "{}";
      frame = JSON.parse(msg);
      if (_ref = !'opcode', __indexOf.call(frame, _ref) >= 0) frame.opcode = 0;
      response = {
        opcode: ERROR,
        data: ""
      };
      switch (frame.opcode) {
        case CONNECT:
          if (__indexOf.call(frame, 'data') >= 0 && frame.data.length > 0) {
            this.effectiveClient.setId(frame.data);
          }
          response.opcode = CONNECT_GRANTED;
          response.data = this.effectiveClient.id;
          break;
        case SUBSCRIBE:
          if (frame.channel.indexOf("private:") >= 0) {
            response.channel = frame.channel;
            response.opcode = SUBSCRIBE_DENIED;
          } else {
            chan = this.effectiveNetwork.findChannel(frame.channel);
            if (!chan) chan = this.effectiveNetwork.addChannel(frame.channel);
            chan.addSubscriber(this.effectiveClient);
            response.channel = chan.name;
            response.opcode = SUBSCRIBE_GRANTED;
          }
          break;
        case UNSUBSCRIBE:
          chan = this.effectiveNetwork.findChannel(frame.channel);
          if (!chan) {
            response.data = "channel does not exist on the connected network";
          } else if (!chan.hasSubscriber(this.effectiveClient)) {
            response.data = "you weren't subscribed to the channel in the first place";
          } else {
            chan.removeSubscriber(this.effectiveClient);
            response.channel = chan.name;
            response.opcode = UNSUBSCRIBE_COMPLETE;
          }
          break;
        case PUBLISH:
          chan = this.effectiveNetwork.findChannel(frame.channel);
          if (!chan) {
            response.data = "channel does not exist on the connected network";
          } else if (!chan.hasPublisher(this.effectiveClient)) {
            response.opcode = PUBLISH_DENIED;
            response.data = "you do not have publishing priviledges on this channel";
          } else if (!chan.hasSubscriber(this.effectiveClient)) {
            return null;
          } else {
            response = frame;
          }
          break;
        case AUTHORIZE:
          if (this.effectiveNetwork.checkNetworkKey(frame.data)) {
            response.opcode = AUTHORIZE_GRANTED;
            this.effectiveNetwork.addAuthorizer(this.effectiveClient);
          } else {
            response.opcode = AUTHORIZE_DENIED;
          }
          break;
        case ERROR:
          response.data = "why you error dog?";
      }
      _opcode = response.opcode.toString(16);
      return JSON.stringify(response);
    };

    return ShoveMockServer;

  })();

  MockSocket = (function() {

    function MockSocket() {
      var network, protocols, url, urlMatches, urlReg;
      url = arguments[0], protocols = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      this.url = url;
      this.protocols = protocols;
      this.extensions = "";
      this.protocol = "";
      this.readyState = this.state('connecting');
      this.bufferedAmount = 0;
      urlReg = /^([\w\d]+):\/\/([^\/]+)\/([^\/]+)(.*?)$/gi;
      urlMatches = urlReg.exec(this.url);
      this.app = urlMatches[3];
      this.server = new ShoveMockServer();
      network = this.server.addNetwork(this.app);
      this.server.setEffectiveNetwork(network);
      this;
    }

    MockSocket.prototype.close = function(code, reason) {
      if (code == null) code = 0;
      if (reason == null) reason = "";
      this.readyState = this.state('closing');
      this.onclose();
      return null;
    };

    MockSocket.prototype.state = function(str) {
      switch (str) {
        case 'connecting':
          return 0;
        case 'open':
          return 1;
        case 'closing':
          return 2;
        case 'closed':
          return 3;
      }
      return null;
    };

    MockSocket.prototype.onopen = function() {};

    MockSocket.prototype.onerror = function() {};

    MockSocket.prototype.onclose = function() {};

    MockSocket.prototype.onmessage = function() {};

    MockSocket.prototype.send = function(msg) {
      var connect_response, frame, response,
        _this = this;
      if (msg == null) msg = "{}";
      if (this.readyState === this.state('open')) {
        response = this.server.process(msg);
        if (response !== null) {
          window.setTimeout((function() {
            return _this.onmessage(response);
          }), 10);
        }
        return this;
      }
      frame = JSON.parse(msg);
      if (frame.opcode) {
        if (frame.opcode === CONNECT) {
          connect_response = JSON.parse(this.server.process(msg));
          if (connect_response.opcode === CONNECT_GRANTED) {
            this.readyState = this.state('open');
            this.onopen();
          }
        }
      }
      return null;
    };

    return MockSocket;

  })();

}).call(this);
