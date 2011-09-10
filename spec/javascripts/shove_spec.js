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
        
    it("should connect", function() {
      Shove.connect("test")

      waitsFor(function() {
        return Shove.transport.state == "CONNECTED";
      }, "Unable to connect", 1000);
      
      runs(function() {
        expect(Shove.transport.state).toEqual("CONNECTED");
      });
    });
    
    it("should have trigged a connect event", function() {
      expect(_connected).toEqual(true);
    });
    
    it("should get an identity", function() {
      expect(Shove.identity()).toMatch(/\w+/);
    });
    
  });


  describe("p2p channel", function() {
    var channel;
    var messages = [];
    
    it("should subscribe to a channel", function() {
      channel = Shove.channel("p2p:test").on("*", function(e) {
        messages.push(e);
      });

      waitsFor(function() {
        return messages.length > 0;
      }, "Channel subscription failed", 100);
    });

    it("should have a message", function() {
      expect(messages.length).toEqual(1)
    });

    it("should receive a subscription event", function() {
      expect(messages.pop().event).toEqual("$subscribed");
    });

    it("should broadcast to a channel", function() {
      channel.broadcast("test", "hey");
      waitsFor(function() {
        return messages.length > 0;
      }, "Channel broadcast failed", 100);
    });

    it("should receive a p2p msg from self", function() {
      var m = messages.pop();
      expect(m.user).toEqual(Shove.identity());
      expect(m.event).toEqual("test");
      expect(m.data).toEqual("hey");
    });

    it("should broadcast data to a channel", function() {
      channel.broadcast("test", JSON.stringify({ funky: "of course" }));
      waitsFor(function() {
        return messages.length > 0;
      }, "Channel broadcast failed", 100);
    });

    it("should receive a p2p data from self", function() {
      var m = messages.pop();
      expect(m.user).toEqual(Shove.identity());
      expect(m.event).toEqual("test");
      expect(m.data).toEqual(JSON.stringify({ funky: "of course" }));
    });
    
    it("should broadcast multibyteto a channel", function() {
      channel.broadcast("test", "测试");
      waitsFor(function() {
        return messages.length > 0;
      }, "Channel broadcast failed", 100);
    });
    
    it("should handle multibyte chars", function() {
      var m = messages.pop();
      expect(m.data).toEqual("测试");
    });
    
    it("should unsubscribe", function() {
      channel.unsubscribe();
      waitsFor(function() {
        return !channel.subscribed;
      }, "Channel unsubscribe failed", 100);
      runs(function() {
        channel.broadcast("test", "bye");
      });
    });

    it("should not receive messages for an unsubscribed channel", function() {
      expect(messages.length).toEqual(0);
    });
    
  });
  
  
  describe("private channel", function() {
    var channel;
    var messages = [];
    var _wait = false;
    
    it("should receive a unauthorized event on a private channel", function() {
      channel = Shove.channel("private:test").on("*", function(e) {
        messages.push(e);
      });

      channel.on("$unauthorized", function() {
        _wait = true;
      });
      
      waitsFor(function() {
        return _wait;
      }, "Channel subscription failed", 100);
    
    });
    
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
    
    it("should subscribe to a presence channel", function() {

      channel = Shove.channel("presence:test").on("*", function(e) {
        messages.push(e);
      });
      
      channel.on("$presence", function() {
        _presence = true;
      });
      
      waitsFor(function() {
        return messages.length == 2;
      }, "Channel broadcast failed", 100);
    });
    
    
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
    
    it("should disconnect, change state", function() {
      Shove.disconnect();

      waitsFor(function() {
        return Shove.transport.state == "DISCONNECTED";
      }, "Unable to disconnect", 1000);
      
    });
        
    it("should disconnect", function() {
      expect(Shove.transport.state).toEqual("DISCONNECTED");
    });
    
    it("should trigger a disconnect event", function() {
      expect(_connected).toEqual(false);
    });
    
  });
  
});
