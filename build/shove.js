(function() {
  var ALLOW_CONNECT, ALLOW_LOG, ALLOW_PUBLISH, ALLOW_SUBSCRIBE, AUTHORIZE, AUTHORIZE_COMPLETE, CONNECT_COMPLETE, CONNECT_DENIED, Client, DENY_CONNECT, DENY_LOG, DENY_PUBLISH, DENY_SUBSCRIBE, ERROR, LOG, LOG_DENIED, LOG_STARTED, PUBLISH, PUBLISH_COMPLETE, PUBLISH_DENIED, SUBSCRIBE, SUBSCRIBE_COMPLETE, SUBSCRIBE_DENIED, UNSUBSCRIBE, UNSUBSCRIBE_COMPLETE;
  var __hasProp = Object.prototype.hasOwnProperty, __slice = Array.prototype.slice;

  ERROR = 0x7F;

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
      var key, val;
      var _this = this;
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

}).call(this);
