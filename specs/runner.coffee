if(typeof exports != "undefined" && exports != null)
  root = exports
else
  root = window
  global = window

class TestRunner
  constructor: (@trace=false) ->
    @errors = 0
    @tests = 0
    @suite = ""

  describe: (text) ->
    @suite = text
    console.log("Running specs for #{text}")

  red: (msg) ->
    "\x1b[31m#{msg}\x1b[0m"
     
  green: (msg) ->
    "\x1b[32m#{msg}\x1b[0m"
  
  areEqual: (a,b) ->
    if a != b
      throw "are not equal"
    this
  
  isTrue: (a) ->
    if !!!a
      throw "is not true"
    this
  
  exists: (a) ->
    if typeof a == "undefined"
      throw "does not exist"
    this
  
  test: (name, fn) ->
    @tests++
    try
      fn()
      console.log(@green("☑ #{@suite} #{name}"))
    catch err
      @errors++
      console.error(@red("☒ #{@suite} #{name}"))

      if @trace && err.hasOwnProperty('stack')
        console.log(err.stack)

  report: () ->
    console.log("-------------------")
    if @errors > 0

      console.error("#{@red('☒')} #{@errors}/#{@tests} tests failed")
    else
      console.log("#{@green('☑')} All tests passed")

root.TestRunner = TestRunner