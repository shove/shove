# shove.io javascript client

The official javascript client library for shove.io.

## Include the Shove Library

Include the latest version of the shove javascript client.

```html
<script type="text/javascript" src="http://cdn.shove.io/shove.min.js"></script>
```

## <a name="shove_networks" ></a>Networks

### <a name="shove_connect" ></a>Connect

Connect the client to your app"s network to enable the client to publish or receive messages from the app and other clients.

```javascript
$shove.connect("{{app_id}}", "{{connect_key}}");
```

### <a name="shove_events" ></a>Bind handlers to shove app networks

Allow your client-side app to respond to network events with the following types:

+ connect
+ connect_denied
+ connecting
+ disconnect
+ handshaking
+ failure
+ reconnect

```javascript
$shove.on("connect", function() {
  console.log("shove network connected");
});
```

### <a name="shove_on_off" ></a>Unbind handlers from shove app networks

In the case of removing bound event handlers, the original function must be used for comparison.

```javascript
var fn = function(){
  console.log("Shove Connected!");
  return true;
};
$shove.on("connect", fn);
$shove.off("connect", fn);
```

### <a name="shove_authorize" ></a>Authentication

It's possible to grant clients publish and subscribe rights on one or more channels.

If your client needs publish/subscribe access on all channels, you can authenticate the client using
the * channel.  This is only recommended if the client is a trusted client.

```javascript
$shove.channel("*").authenticate("sub or channel key");
```

To generate keys see the [Channel Keys](https://github.com/shove/shove-ruby#channel_keys "Shove-Ruby:Channel Keys") section of the [shove-ruby](https://github.com/shove/shove-ruby "Shove-Ruby") implementation.

```javascript
$shove.channel("channel").authenticate("channel_key");
```

## <a name="channels" ></a>Channels
### <a name="channel_subscribe" ></a>Subscribe

Channels that do not exist will be created automatically by the Shove server.  Bind handlers using the following event types:

+ message
+ publish_denied
+ publish_granted
+ subscribe
+ subscribing
+ subscribe_denied
+ unsubscribe
+ unsubscribing

```javascript
var channel = $shove.channel("channel_name");

channel.on("subscribe", function() {
  console.log("you are subscribed to this channel!");
});

channel.on("unauthorized", function() {
  console.log("channel subscribe failed, not authorized!");
});
```

As soon as you bind a handler to the channel you will start to receive messages.

### <a name="channel_unsubscribe" ></a>Unsubscribe from Channels

A client will cease to receive messages from a channel when unsubscribed.

```javascript
channel.unsubscribe();
```

### <a name="channel_filters" ></a>Add filters to easily modify incoming messages

Filters are applied to incoming messages before the "message" event is fired.  Message processing can be halted if a filter returns `false`.

```javascript
// replaces occurrences of "hello" with "HULLO" for all messages received
channel.filter(function(msg,from) {
  if(msg.hasOwnProperty("data") && typeof msg.data == "string") {
    msg.data = msg.data.replace("hello","HULLO");
  }
  return msg;
});

// Halt messages that contain profanity
channel.filter(function(msg,from) {
  if(msg.hasOwnProperty("data") && typeof msg.data == "string"){
    if(msg.data.search(/(bad|words)/gi) >= 0)
      return false;
  }
  return msg;
});

channel.on("message", function(msg) {
  // handle message as you see fit
});
```

### Access to active filters

An array of bound filter functions can be obtained by omitting a function argument.

```javascript
console.log(channel.filter().length + " filters are currently in the message pipeline.");
```

### <a name="channel_publish" ></a>Publish Messages

If publishing is allowed on all channels by default, or if the client application has already authorized itself then sending messages is simple.  Messages should be simple strings, if a message needs to be more complex use `JSON.stringify()` and `JSON.parse()` to encode and decode objects.

```javascript
channel.publish("message here");

var complexMessage = {
  x: 0,
  y: 100,
  l: 42
};
channel.publish(JSON.stringify(complexMessage));
```

A filter can be applied to all incoming messages to handle the decoding of data.

```javascript
channel.filter(function(m,from) {
  return JSON.parse(m);
});
```

Or if not all messages need to be complex objects then perhaps multiple channels should be used.

```javascript
var simpleChannel = $shove.channel("channel-a");
var complexChannel = $shove.channel("channel-b");

simpleChannel.on("message", function(message, from) { 
  // handle incoming simple (string) messages
  console.log(typeof message);
});

complexChannel.on("message", function(message, from) {
  // handle incoming object messages
  console.log(typeof message);
})

simpleChannel.publish("simple messages abound!");

complexChannel.filter(function(m,from) {
  return JSON.parse(m);
});

complexChannel.publish(JSON.stringify({
  x: 0,
  y: 100,
  l: 42
}));
```
