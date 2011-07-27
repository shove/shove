describe("Shove", function() {

  var _connected = false, _connecting = false;
    
  describe("connection", function() {

    Shove.on("connecting", function() {
      _connecting = true;
    }).on("connect", function() {
      _connected = true;
    }).on("disconnect", function() {
      _connected = false;
    });
    
    Shove.on("*", function(e) {
      console.log(e);
    });
    
    Shove.connect("deadbeef")

    it("should connect", function() {
      expect(_connecting).toEqual(true);
    });
      
    // wait hack?
    runs(function() {
    });
    waits(20);
  });


  it("should be connected", function() {
    expect(Shove.transport.connected).toEqual(true);
    expect(_connected).toEqual(true);
  });
    
  it("should have an identity", function() {
    expect(Shove.identity()).toMatch(/\w+/);
  });
  
  describe("p2p channel", function() {
    var channel;
    var messages = [];
    
    runs(function() {
      channel = Shove.channel("p2p:test").on("*", function(e) {
        messages.push(e);
      })
    });
    waits(20);
    
    it("should have a message", function() {
      expect(messages.length).toEqual(1)
    });
    
    it("should receive a subscription event", function() {
      expect(messages.pop().event).toEqual("$subscribed");
    });

    runs(function() {
      channel.broadcast("test", "hey");
    });
    waits(20);
    
    it("should receive a p2p msg from self", function() {
      var m = messages.pop();
      expect(m.user).toEqual(Shove.identity());
      expect(m.event).toEqual("test");
      expect(m.data).toEqual("hey");
    });
    
    runs(function() {
      channel.broadcast("test", "测试");
    });
    waits(20);
    
    it("should handle multibyte chars", function() {
      var m = messages.pop();
      console.log(m);
      expect(m.data).toEqual("测试");
    });
    
    runs(function() {
      channel.unsubscribe();
    });
    waits(20);
    
    runs(function() {
      channel.broadcast("test", "bye");
    });
    waits(50);
    
    it("should not receive messages for an unsubscribed channel", function() {
      expect(messages.length).toEqual(0);
    });

    
  });
  
  describe("private channel", function() {
    var channel;
    var messages = [];
    var _wait = false;
    
    runs(function() {
      channel = Shove.channel("private:test").on("*", function(e) {
        messages.push(e);
      });
      
      channel.on("$unauthorized", function() {
        _wait = true;
      });

    });
    waits(20);
    
    it("should have a message", function() {
      expect(messages.length).toEqual(1)
    });
    
    it("should receive a unauthorized event", function() {
      expect(messages.pop().event).toEqual("$unauthorized");
    });

    it("should trigger a unauthorized event", function() {
      expect(_wait).toEqual(true);
    });
    
  });

  describe("presence channel", function() {
    var channel;
    var messages = [];
    var _presence = false;
    
    runs(function() {
      channel = Shove.channel("presence:test").on("*", function(e) {
        messages.push(e);
      });
      
      channel.on("$presence", function() {
        _presence = true;
      });

    });
    waits(20);
    
    it("should have a message", function() {
      expect(messages.length).toEqual(2)
    });
    
    it("should receive subscribed and presence event", function() {
      expect(messages.shift().event).toEqual("$subscribed");
      expect(messages.shift().event).toEqual("$presence");
    });

    it("should trigger a presence event", function() {
      expect(_presence).toEqual(true);
    });
    
  });
  

  describe("disconnect", function() {
    runs(function() {
      Shove.disconnect();
    });
    waits(20);
  });
  
  it("should disconnect", function() {
    expect(Shove.transport.connected).toEqual(false);
  });
  
  it("should trigger a disconnect event", function() {
    expect(_connected).toEqual(false);
  });

});
