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


  describe("publisher", function() {
    var channel;
    var messages = [];
    
    it("should authorize", function() {
      // authorize admin
      Shove.authorize("test");

      waitsFor(function() {
        return Shove.authorized;
      }, "App authorization failed", 100);
    });

    it("should subscribe to a channel", function() {

      channel = Shove.channel("publish").on("*", function(e) {
        messages.push(e);
      });

      waitsFor(function() {
        return channel.state == "subscribed";
      }, "Channel subscription failed", 100);
    });

    it("should have a message", function() {
      expect(messages.length).toEqual(1)
    });

    it("should receive a subscription event", function() {
      expect(messages.pop().event).toEqual("subscribed");
    });

    it("should publish to a channel", function() {
      channel.publish("test", "hey");
      waitsFor(function() {
        return messages.length > 0;
      }, "Channel publish failed", 200);
    });

    it("should receive a p2p msg from self", function() {
      var m = messages.pop();
      expect(m.user).toEqual(Shove.identity());
      expect(m.event).toEqual("test");
      expect(m.data).toEqual("hey");
    });

    it("should publish data to a channel", function() {
      channel.publish("test", JSON.stringify({ funky: "of course" }));
      waitsFor(function() {
        return messages.length > 0;
      }, "Channel publish failed", 100);
    });

    it("should receive data from self", function() {
      var m = messages.pop();
      expect(m.user).toEqual(Shove.identity());
      expect(m.event).toEqual("test");
      expect(m.data).toEqual(JSON.stringify({ funky: "of course" }));
    });
    
    it("should publish multibyteto a channel", function() {
      channel.publish("test", "测试");
      waitsFor(function() {
        return messages.length > 0;
      }, "Channel publish failed", 100);
    });
    
    it("should handle multibyte chars", function() {
      var m = messages.pop();
      expect(m.data).toEqual("测试");
    });
    
    it("should unsubscribe", function() {
      channel.unsubscribe();
      waitsFor(function() {
        return channel.state == "unsubscribed";
      }, "Channel unsubscribe failed", 100);
      runs(function() {
        channel.publish("test", "bye");
      });
    });
    
  });
  
  
  describe("private channel", function() {
    var channel;
    var unauthorized = false;
    
    it("should receive a unauthorized event on a private channel", function() {
      channel = Shove.channel("private:test").on("unauthorized", function(e) {
        unauthorized = true;
      });

      waitsFor(function() {
        return channel.state == "unauthorized";
      }, "Channel subscription failed", 100);
    
    });
    
    it("should receive a unauthorized event", function() {
      expect(channel.state).toEqual("unauthorized");
    });

    it("should trigger a unauthorized event", function() {
      expect(unauthorized).toEqual(true);
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
      
      channel.on("presence", function() {
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
      expect(messages.shift().event).toEqual("subscribed");
      expect(messages.shift().event).toEqual("presence");
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
