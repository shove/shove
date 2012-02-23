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

errors = 0


# Ref the active backdoor websocket
backdoor = null

# Mock we can inject into
class WebSocket

  constructor: () ->
    @queue = []
    backdoor = this

  send: (m) ->
    @queue.push(m)

  clear: () ->
    @queue = []

  pop: () ->
    @queue.pop()

  inject: (m) ->
    @onmessage(JSON.stringify({
      data: m
    }))

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


runner.report()