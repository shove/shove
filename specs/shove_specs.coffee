tRunner = require("./runner.coffee")
shove  = require("../shove.coffee").$shove

# Opcodes
ERROR = 0x00
CONNECT = 0x01
CONNECT_GRANTED = 0x02
CONNECT_DENIED = 0x03
DISCONNECT = 0x04
DISCONNECT_COMPLETE = 0x06
SUBSCRIBE = 0x10
SUBSCRIBE_GRANTED = 0x11
SUBSCRIBE_DENIED = 0x12
UNSUBSCRIBE = 0x13
UNSUBSCRIBE_COMPLETE = 0x14
PUBLISH = 0x20 
PUBLISH_DENIED = 0x21
PUBLISH_GRANTED = 0x22
GRANT_PUBLISH = 0x30 
GRANT_SUBSCRIBE = 0x31
GRANT_CONNECT = 0x32
GRANT_CONTROL = 0x33
DENY_PUBLISH = 0x40 
DENY_SUBSCRIBE = 0x41
DENY_CONNECT = 0x42
DENY_CONTROL = 0x43
LOG = 0x50 
LOG_STARTED = 0x51
LOG_DENIED = 0x52
AUTHORIZE = 0x60
AUTHORIZE_GRANTED = 0x61
AUTHORIZE_DENIED = 0x62
PRESENCE_SUBSCRIBED = 0x70
PRESENCE_UNSUBSCRIBED = 0x71
PRESENCE_LIST = 0x72

SUBSCRIBING_STATE = 0x1
SUBSCRIBED_STATE = 0x2
UNSUBSCRIBED_STATE = 0x3
UNSUBSCRIBING_STATE = 0x4
UNAUTHORIZED_STATE = 0x5

errors = 0

filter = (m) ->
  "!#{m}!"

# Ref the active backdoor websocket
backdoor = null

# Mock we can inject into
class WebSocket

  constructor: () ->
    @queue = []
    backdoor = this

  send: (m) ->
    @queue.push(JSON.parse(m))

  clear: () ->
    @queue = []

  pop: () ->
    @queue.pop()

  inject: (m) ->
    @onmessage({
      data: JSON.stringify(m)
    })

# Setup global scope for backdoor action
global.WebSocket = WebSocket

# Run it

runner = new tRunner.TestRunner(true)

runner.describe("Shove")

runner.test "should have a version", () ->
  runner.exists shove.Version

runner.test "Should enable debugging",() ->
  runner.isTrue shove.debug(true)

runner.test "should disable debugging",() ->
  runner.isTrue !shove.debug(false)

runner.test "should fail in attempt to bind to unknown events",() ->
  fn = () ->
    return 0
  result = shove.on("non_event",fn)
  runner.isTrue(!result)

runner.test "should remove bound event callbacks",() ->
  e = "connect"
  fn = () ->
    return 0
  shove.on e,fn
  shove.off e,fn
  callbackExists = false
  for cb in shove.events[e]
    if cb == fn
      callbackExists = true
      break
  runner.isTrue !callbackExists

runner.test("should attempt to connect", () ->
  shove.connect("app",{hosts:"app-aspen-1.shove.io"})
  runner.areEqual(shove.app,"app")
  runner.exists(shove.transport))

runner.test("should attempt to connect", () ->
  trig = false
  shove.on("connecting", () ->
    trig = true)

  shove.connect("app")
  runner.areEqual(shove.app,"app")

  runner.isTrue(trig))

runner.test("should trigger handshake event", () ->
  trig = false
  shove.on("handshaking", () ->
    trig = true)

  backdoor.onopen();

  runner.isTrue(trig))

runner.test("should send a connect op", () ->
  runner.areEqual(backdoor.pop().opcode,CONNECT))

runner.test("should trigger connected event", () ->
  trig = false
  shove.on("connect", () ->
    trig = true)

  backdoor.inject({
    opcode: CONNECT_GRANTED,
    data: "idx"
  })

  runner.isTrue(trig))


runner.test("should have an id", () ->
  runner.areEqual(shove.id,"idx"))

runner.test("should attempt to authorize", () ->
  shove.authenticate("key")
  runner.areEqual(shove.key, "key")
  msg = backdoor.pop()
  runner.areEqual(msg.opcode,AUTHORIZE)
  runner.areEqual(msg.data,"key"))

runner.test("should trigger authorize denied", () ->
  trig = false
  shove.on("authorize_denied", () ->
    trig = true)
  
  backdoor.inject({
    opcode: AUTHORIZE_DENIED
  })

  runner.isTrue(trig))

runner.test("should trigger authorize granted", () ->
  trig = false
  shove.on("authorize", () ->
    trig = true)
  
  backdoor.inject({
    opcode: AUTHORIZE_GRANTED
  })

  runner.isTrue(trig))

runner.describe("Channels")

runner.test("should start subscribing to a channel", () ->
  trig = false
  shove.channel("c1").on("subscribing", () ->
    trig = true)
  runner.areEqual(shove.channel("c1").state,SUBSCRIBING_STATE)
  runner.isTrue(trig)
  )

runner.test "should fail in attempt to bind to unknown events", () ->
  fn = () ->
    return 0
  result = shove.channel("c1").on("non_event",fn)
  runner.isTrue(!result)

runner.test "should remove bound event callbacks", () ->
  c = "c1"
  e = "subscribe"
  fn = () ->
    return 0
  shove.channel(c).on e,fn
  shove.channel(c).off e,fn
  callbackExists = false
  for cb in shove.channel(c).events[e]
    if cb == fn
      callbackExists = true
      break
  runner.isTrue !callbackExists

runner.test("should handle subscribe_denied event", () ->
  trig = false
  shove.channel("c1").on("subscribe_denied", () ->
    trig = true)

  backdoor.inject({
    opcode: SUBSCRIBE_DENIED,
    channel: "c1"
  })

  runner.areEqual(shove.channel("c1").state,UNAUTHORIZED_STATE)
  runner.isTrue(trig)
  )

runner.test("should handle subscribed event", () ->
  trig = false
  shove.channel("c1").on("subscribe", () ->
    trig = true)

  backdoor.inject({
    opcode: SUBSCRIBE_GRANTED,
    channel: "c1"
  })

  runner.areEqual(shove.channel("c1").state,SUBSCRIBED_STATE)
  runner.isTrue(trig)
  )

runner.test("should handle message events", () ->
  m = null
  shove.channel("c1").on("message", (m_) ->
    m = m_)

  backdoor.inject({
    opcode: PUBLISH,
    channel: "c1",
    data: "test message"
  })

  runner.areEqual(m,"test message")
  )

runner.test("should handle message events with from data", () ->
  m = null
  f = null
  shove.channel("c1").on("message", (m_, f_) ->
      m = m_
      f = f_)

  backdoor.inject({
    opcode: PUBLISH,
    channel: "c1",
    data: "test message",
    from: "dan"
  })

  runner.areEqual(m,"test message")
  runner.areEqual(f,"dan")
  )

runner.test("should run messages through filters", () ->

  c = shove.channel("c1")

  c.filter(filter)

  m = null
  c.on("message", (m_) ->
    m = m_)

  tm = "test"
  backdoor.inject({
    opcode: PUBLISH,
    channel: "c1",
    data: tm
  })

  runner.areEqual(filter(tm),m)
  )

runner.test("should handle publish_denied event", () ->
  cn = "c1"
  tm = "test message, should be denied"
  
  c = shove.channel(cn)
  
  pubDenied = false
  c.on("publish_denied", (m_) ->
    pubDenied = true)
  
  c.publish(tm)
  
  backdoor.inject({
    opcode: PUBLISH_DENIED,
    channel: cn
  })
  
  runner.isTrue(pubDenied)
  
  )

runner.test "should handle publish_granted event", () ->
  cn = "c1"
  cKey = "c1-key"
  
  c = shove.channel(cn)
  
  pubGranted = false
  c.on("publish_granted",(m_) ->
    pubGranted = true)
  
  c.authenticate(cKey)
  
  backdoor.inject({
    opcode: AUTHORIZE_GRANTED,
    channel: cn
  })
  
  runner.isTrue(pubGranted)

runner.test "should receive published message",() ->
  cn = "c1"
  c = shove.channel(cn)
  tm = "test message, should be received"
  m = null

  c.on("message", (m_) ->
    m = m_
    )
  
  c.publish(tm)
  
  backdoor.inject({
    opcode: PUBLISH,
    channel: cn,
    data: tm
  })
  
  runner.areEqual(filter(tm),m)


runner.test "should start unsubscribing", () ->
  trig = false
  shove.channel("c1").on("unsubscribing", () ->
    trig = true)
  shove.channel("c1").unsubscribe()
  runner.areEqual(shove.channel("c1").state,UNSUBSCRIBING_STATE)
  runner.isTrue(trig)


runner.test "should unsubscribe", () ->
  trig = false
  shove.channel("c1").on("unsubscribe", () ->
    trig = true)
  backdoor.inject({
    opcode: UNSUBSCRIBE_COMPLETE,
    channel: "c1"
  })
  runner.areEqual(shove.channel("c1").state,UNSUBSCRIBED_STATE)
  runner.isTrue(trig)


runner.report()