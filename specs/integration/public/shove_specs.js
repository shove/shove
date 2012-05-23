// Generated by CoffeeScript 1.3.1
var AUTHORIZE, AUTHORIZE_DENIED, AUTHORIZE_GRANTED, CONNECT, CONNECT_DENIED, CONNECT_GRANTED, DENY_CONNECT, DENY_CONTROL, DENY_PUBLISH, DENY_SUBSCRIBE, DISCONNECT, DISCONNECT_COMPLETE, ERROR, GRANT_CONNECT, GRANT_CONTROL, GRANT_PUBLISH, GRANT_SUBSCRIBE, LOG, LOG_DENIED, LOG_STARTED, PRESENCE_LIST, PRESENCE_SUBSCRIBED, PRESENCE_UNSUBSCRIBED, PUBLISH, PUBLISH_DENIED, PUBLISH_GRANTED, SUBSCRIBE, SUBSCRIBED_STATE, SUBSCRIBE_DENIED, SUBSCRIBE_GRANTED, SUBSCRIBING_STATE, UNAUTHORIZED_STATE, UNSUBSCRIBE, UNSUBSCRIBED_STATE, UNSUBSCRIBE_COMPLETE, UNSUBSCRIBING_STATE, WebSocket, backdoor, errors, filter, runner, shove, tRunner;

tRunner = require("./runner.coffee");

shove = require("../shove.coffee").$shove;

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

SUBSCRIBING_STATE = 0x1;

SUBSCRIBED_STATE = 0x2;

UNSUBSCRIBED_STATE = 0x3;

UNSUBSCRIBING_STATE = 0x4;

UNAUTHORIZED_STATE = 0x5;

errors = 0;

filter = function(m) {
  return "!" + m + "!";
};

backdoor = null;

WebSocket = (function() {

  WebSocket.name = 'WebSocket';

  function WebSocket() {
    this.queue = [];
    backdoor = this;
  }

  WebSocket.prototype.send = function(m) {
    return this.queue.push(JSON.parse(m));
  };

  WebSocket.prototype.clear = function() {
    return this.queue = [];
  };

  WebSocket.prototype.pop = function() {
    return this.queue.pop();
  };

  WebSocket.prototype.inject = function(m) {
    return this.onmessage({
      data: JSON.stringify(m)
    });
  };

  return WebSocket;

})();

global.WebSocket = WebSocket;

runner = new tRunner.TestRunner(true);

runner.describe("Shove");

runner.test("should have a version", function() {
  return runner.exists(shove.Version);
});

runner.test("Should enable debugging", function() {
  return runner.isTrue(shove.debug(true));
});

runner.test("should disable debugging", function() {
  return runner.isTrue(!shove.debug(false));
});

runner.test("should fail in attempt to bind to unknown events", function() {
  var fn, result;
  fn = function() {
    return 0;
  };
  result = shove.on("non_event", fn);
  return runner.isTrue(!result);
});

runner.test("should remove bound event callbacks", function() {
  var callbackExists, cb, e, fn, _i, _len, _ref;
  e = "connect";
  fn = function() {
    return 0;
  };
  shove.on(e, fn);
  shove.off(e, fn);
  callbackExists = false;
  _ref = shove.events[e];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    cb = _ref[_i];
    if (cb === fn) {
      callbackExists = true;
      break;
    }
  }
  return runner.isTrue(!callbackExists);
});

runner.test("should attempt to connect", function() {
  shove.connect("app", "key", {
    hosts: ["app-aspen-1.shove.io"]
  });
  runner.areEqual(shove.app, "app");
  runner.areEqual(shove.connectKey, "key");
  return runner.exists(shove.transport);
});

runner.test("should attempt to connect", function() {
  var trig;
  trig = false;
  shove.on("connecting", function() {
    return trig = true;
  });
  shove.connect("app", "key");
  return runner.isTrue(trig);
});

runner.test("should trigger handshake event", function() {
  var trig;
  trig = false;
  shove.on("handshaking", function() {
    return trig = true;
  });
  backdoor.onopen();
  return runner.isTrue(trig);
});

runner.test("should send a connect op", function() {
  return runner.areEqual(backdoor.pop().opcode, CONNECT);
});

runner.test("should trigger connected event", function() {
  var trig;
  trig = false;
  shove.on("connect", function() {
    return trig = true;
  });
  backdoor.inject({
    opcode: CONNECT_GRANTED,
    data: "idx"
  });
  return runner.isTrue(trig);
});

runner.test("should have an id", function() {
  return runner.areEqual(shove.id, "idx");
});

runner.test("should attempt to authorize", function() {
  var msg;
  shove.authenticate("key");
  runner.areEqual(shove.key, "key");
  msg = backdoor.pop();
  runner.areEqual(msg.opcode, AUTHORIZE);
  return runner.areEqual(msg.data, "key");
});

runner.test("should trigger authorize denied", function() {
  var trig;
  trig = false;
  shove.on("authorize_denied", function() {
    return trig = true;
  });
  backdoor.inject({
    opcode: AUTHORIZE_DENIED
  });
  return runner.isTrue(trig);
});

runner.test("should trigger authorize granted", function() {
  var trig;
  trig = false;
  shove.on("authorize", function() {
    return trig = true;
  });
  backdoor.inject({
    opcode: AUTHORIZE_GRANTED
  });
  return runner.isTrue(trig);
});

runner.describe("Channels");

runner.test("should start subscribing to a channel", function() {
  var trig;
  trig = false;
  shove.channel("c1").on("subscribing", function() {
    return trig = true;
  });
  runner.areEqual(shove.channel("c1").state, SUBSCRIBING_STATE);
  return runner.isTrue(trig);
});

runner.test("should fail in attempt to bind to unknown events", function() {
  var fn, result;
  fn = function() {
    return 0;
  };
  result = shove.channel("c1").on("non_event", fn);
  return runner.isTrue(!result);
});

runner.test("should remove bound event callbacks", function() {
  var c, callbackExists, cb, e, fn, _i, _len, _ref;
  c = "c1";
  e = "subscribe";
  fn = function() {
    return 0;
  };
  shove.channel(c).on(e, fn);
  shove.channel(c).off(e, fn);
  callbackExists = false;
  _ref = shove.channel(c).events[e];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    cb = _ref[_i];
    if (cb === fn) {
      callbackExists = true;
      break;
    }
  }
  return runner.isTrue(!callbackExists);
});

runner.test("should handle subscribe_denied event", function() {
  var trig;
  trig = false;
  shove.channel("c1").on("subscribe_denied", function() {
    return trig = true;
  });
  backdoor.inject({
    opcode: SUBSCRIBE_DENIED,
    channel: "c1"
  });
  runner.areEqual(shove.channel("c1").state, UNAUTHORIZED_STATE);
  return runner.isTrue(trig);
});

runner.test("should handle subscribed event", function() {
  var trig;
  trig = false;
  shove.channel("c1").on("subscribe", function() {
    return trig = true;
  });
  backdoor.inject({
    opcode: SUBSCRIBE_GRANTED,
    channel: "c1"
  });
  runner.areEqual(shove.channel("c1").state, SUBSCRIBED_STATE);
  return runner.isTrue(trig);
});

runner.test("should handle message events", function() {
  var m;
  m = null;
  shove.channel("c1").on("message", function(m_) {
    return m = m_;
  });
  backdoor.inject({
    opcode: PUBLISH,
    channel: "c1",
    data: "test message"
  });
  return runner.areEqual(m, "test message");
});

runner.test("should handle message events with from data", function() {
  var f, m;
  m = null;
  f = null;
  shove.channel("c1").on("message", function(m_, f_) {
    m = m_;
    return f = f_;
  });
  backdoor.inject({
    opcode: PUBLISH,
    channel: "c1",
    data: "test message",
    from: "dan"
  });
  runner.areEqual(m, "test message");
  return runner.areEqual(f, "dan");
});

runner.test("should run messages through filters", function() {
  var c, m, tm;
  c = shove.channel("c1");
  c.filter(filter);
  m = null;
  c.on("message", function(m_) {
    return m = m_;
  });
  tm = "test";
  backdoor.inject({
    opcode: PUBLISH,
    channel: "c1",
    data: tm
  });
  return runner.areEqual(filter(tm), m);
});

runner.test("should handle publish_denied event", function() {
  var c, cn, pubDenied, tm;
  cn = "c1";
  tm = "test message, should be denied";
  c = shove.channel(cn);
  pubDenied = false;
  c.on("publish_denied", function(m_) {
    return pubDenied = true;
  });
  c.publish(tm);
  backdoor.inject({
    opcode: PUBLISH_DENIED,
    channel: cn
  });
  return runner.isTrue(pubDenied);
});

runner.test("should handle publish_granted event", function() {
  var c, cKey, cn, pubGranted;
  cn = "c1";
  cKey = "c1-key";
  c = shove.channel(cn);
  pubGranted = false;
  c.on("publish_granted", function(m_) {
    return pubGranted = true;
  });
  c.authenticate(cKey);
  backdoor.inject({
    opcode: AUTHORIZE_GRANTED,
    channel: cn
  });
  return runner.isTrue(pubGranted);
});

runner.test("should receive published message", function() {
  var c, cn, m, tm;
  cn = "c1";
  c = shove.channel(cn);
  tm = "test message, should be received";
  m = null;
  c.on("message", function(m_) {
    return m = m_;
  });
  c.publish(tm);
  backdoor.inject({
    opcode: PUBLISH,
    channel: cn,
    data: tm
  });
  return runner.areEqual(filter(tm), m);
});

runner.test("should start unsubscribing", function() {
  var trig;
  trig = false;
  shove.channel("c1").on("unsubscribing", function() {
    return trig = true;
  });
  shove.channel("c1").unsubscribe();
  runner.areEqual(shove.channel("c1").state, UNSUBSCRIBING_STATE);
  return runner.isTrue(trig);
});

runner.test("should unsubscribe", function() {
  var trig;
  trig = false;
  shove.channel("c1").on("unsubscribe", function() {
    return trig = true;
  });
  backdoor.inject({
    opcode: UNSUBSCRIBE_COMPLETE,
    channel: "c1"
  });
  runner.areEqual(shove.channel("c1").state, UNSUBSCRIBED_STATE);
  return runner.isTrue(trig);
});

runner.report();
