coffee = require("coffee-script")
should = require("should")
reader = require("fs")
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

class TestRunner
  constructor: (trace=false) ->
    @errors = 0
    @tests = 0
    @trace = trace
    @suite = ""

  describe: (text) ->
    @suite = text
    console.log("Running specs for #{text}")

  red: (msg) ->
    "\x1b[31m#{msg}\x1b[0m"
     
  green: (msg) ->
    "\x1b[32m#{msg}\x1b[0m"

  test: (name, fn) ->
    @tests++
    try
      fn()
      console.log(@green("☑ #{@suite} #{name}"));
    catch err
      @errors++
      console.log(@red("☒ #{@suite} #{name}"))

      if @trace
        console.log(err.stack)

  report: () ->
    console.log("-------------------")
    if @errors > 0

      console.log("#{@red('☒')} #{@errors}/#{@tests} tests failed")
    else
      console.log("#{@green('☑')} All tests passed")

# Run it

runner = new TestRunner(true)
runner.start
runner.describe("Shove")

runner.test("should have a version", () ->
  shove.Version.should.exist)


runner.test("should attempt to connect", () ->
  shove.connect("app")
  shove.app.should.equal("app")
  shove.transport.should.exist)


runner.test("should attempt to connect", () ->
  trig = false
  shove.on("connecting", () ->
    trig = true)

  shove.connect("app")
  shove.app.should.equal("app")

  trig.should.true)

runner.test("should trigger handshake event", () ->
  trig = false
  shove.on("handshaking", () ->
    trig = true)

  backdoor.onopen();

  trig.should.true)

runner.test("should send a connect op", () ->
  backdoor.pop().opcode.should.equal(CONNECT))

runner.test("should trigger connected event", () ->
  trig = false
  shove.on("connect", () ->
    trig = true)

  backdoor.inject({
    opcode: CONNECT_GRANTED,
    data: "idx"
  })

  trig.should.true)


runner.test("should have an id", () ->
  shove.id.should.equal("idx"))

runner.test("should attempt to authorize", () ->
  shove.authorize("key")
  shove.appKey.should.equal("key")
  msg = backdoor.pop()
  msg.opcode.should.equal(AUTHORIZE)
  msg.data.should.equal("key"))

runner.test("should trigger authorize denied", () ->
  trig = false
  shove.on("authorize_denied", () ->
    trig = true)
  
  backdoor.inject({
    opcode: AUTHORIZE_DENIED
  })

  trig.should.true)

runner.test("should trigger authorize granted", () ->
  trig = false
  shove.on("authorize", () ->
    trig = true)
  
  backdoor.inject({
    opcode: AUTHORIZE_GRANTED
  })

  trig.should.true)

runner.describe("Channels")

runner.test("should start subscribing to a channel", () ->
  trig = false
  shove.channel("c1").on("subscribing", () ->
    trig = true)
  shove.channel("c1").state.should.equal(SUBSCRIBING_STATE)
  trig.should.true
  )

runner.test("should handle unauthorized event", () ->
  trig = false
  shove.channel("c1").on("unauthorized", () ->
    trig = true)

  backdoor.inject({
    opcode: SUBSCRIBE_DENIED,
    channel: "c1"
  })

  shove.channel("c1").state.should.equal(UNAUTHORIZED_STATE)
  trig.should.true
  )

runner.test("should handle subscribed event", () ->
  trig = false
  shove.channel("c1").on("subscribe", () ->
    trig = true)

  backdoor.inject({
    opcode: SUBSCRIBE_GRANTED,
    channel: "c1"
  })

  shove.channel("c1").state.should.equal(SUBSCRIBED_STATE)
  trig.should.true
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

  m.should.equal("test message")
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

  m.should.equal("test message")
  f.should.equal("dan")
  )

runner.test("should run messages through filters", () ->

  c = shove.channel("c1")

  c.filter((m_) ->
    "!#{m_}!")

  m = null
  c.on("message", (m_) ->
    m = m_)

  backdoor.inject({
    opcode: PUBLISH,
    channel: "c1",
    data: "test"
  })

  m.should.equal("!test!")
  )

runner.test("should start unsubscribing", () ->
  trig = false
  shove.channel("c1").on("unsubscribing", () ->
    trig = true)
  shove.channel("c1").unsubscribe()
  shove.channel("c1").state.should.equal(UNSUBSCRIBING_STATE)
  trig.should.true
  )

runner.test("should unsubscribe", () ->
  trig = false
  shove.channel("c1").on("unsubscribe", () ->
    trig = true)
  backdoor.inject({
    opcode: UNSUBSCRIBE_COMPLETE,
    channel: "c1"
  })
  shove.channel("c1").state.should.equal(UNSUBSCRIBED_STATE)
  trig.should.true
  )

runner.report()