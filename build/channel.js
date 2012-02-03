(function() {
  var Channel;

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

}).call(this);
