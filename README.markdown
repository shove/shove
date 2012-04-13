# Shove.io Javascript Client

This is the javascript client library for shove.io, the SaaS for web push.  Hosting your own version of the script is not supported
since the javascript is modified with cluster information on request.  You can, however, look here if you are curious.

For a full overview of the client and instructions on how to use it,
please check out the [shove.io javascript documentation](http://shove.io/documentation/javascript_api)

## Include the Shove Library

Include the latest stable version of the shove javascript client.

```html
<script type="text/javascript" src="http://cdn.shove.io/shove.min.js"></script>
```

## Connect to an App Network

### <a name="shove_connect" />Connect

Connect the client to your app's network to enable the client to publish or receive messages from the app and perhaps other clients.

```javascript
$shove.connect('test-network');
```

### <a name="shove_events" />Bind handlers to shove app networks

Allow your client-side app to respond to network connection events with the following types:

+ authorize
+ authorize_denied
+ connect
+ connecting
+ disconnect
+ handshaking
+ failure
+ reconnect

```javascript
$shove.on('connect', function() {
  console.log('shove network connected');
  return;
});

$shove.on('authorize', function() {
  console.log('shove network authorized, feel free to publish to all channels');
  return;
});
```

### <a name="shove_on_off" />Unbind handlers from shove app networks

In the case of removing bound event handlers, the original function must be used for comparison.

```javascript
var fn = function(){
  console.log('Shove Connected!');
  return true;
};
$shove.on('connect',fn);
$shove.off('connect',fn);
```

### <a name="shove_authorize" />Self Authorize

In some cases it may be beneficial to have a client authorized to publish on all channels, perhaps a private version of the client not open to the public.  Supplying an `app_key` and using the `authorize` method will grant full publishing permissions on all channels for the client.  Channels will still have to be subscribed to individually.

```javascript
$shove.app_key = 'test-network-app-key';
$shove.authorize();
```

## <a name="channels" />Channels
### <a name="channel_subscribe" />Subscribe

Channels that do not exist will be created automatically by the Shove server.  Bind handlers using the following event types:

+ message
+ publish_denied
+ publish_granted
+ subscribe
+ subscribing
+ unauthorized
+ unsubscribe
+ unsubscribing

```javascript
channel = $shove.channel('test-channel');
channel.subscribe();
channel.on('subscribe', function() {
  console.log('you are subscribed to this channel!');
  return;
});
channel.on('unauthorized',function(){
  console.log('channel subscribed failed, not authorized!');
  return;
});
```

### <a name="channel_unsubscribe" />Unsubscribe from Channels

A client will cease to receive messages from a channel when unsubscribed.

```javascript
channel.unsubscribe();
```

### <a name="channel_filters" />Add filters to easily modify incoming messages

Filters are applied to incoming messages before the 'message' event is fired.  Message processing can be halted if a filter returns `false`.

```javascript
/* Filter replaces occurrences of 'hello' with 'HULLO' within message data strings */
channel.filter(function(msg){
  if(msg.hasOwnProperty('data') && typeof msg.data == 'string') {
    msg.data = msg.data.replace('hello','HULLO');
  }
  return msg;
});

/* Halt messages that contain profanity */
channel.filter(function(msg){
  if(msg.hasOwnProperty('data') && typeof msg.data == 'string'){
    if(msg.data.search(/(poop|fanny)/gi) >= 0)
      return false;
  }
  return msg;
});

channel.on('message',function(msg){
  /* present message to user or hand off to client application */
  return;
});
```

### Access to active filters

An array of bound filter functions can be obtained by omitting a function argument.

```javascript
console.log(channel.filter().length + ' filters are currently in the message pipeline.');
```

### <a name="channel_publish" />Publish Messages

If publishing is allowed on all channels by default, or if the client application has already authorized itself then sending messages is simple.  Messages should be simple strings, if a message needs to be more complex use `JSON.stringify()` and `JSON.parse()` to encode and decode objects.

```javascript
channel.publish('message here');

var complexMessage = {
  x:0,
  y:100,
  l:42
};
channel.publish(JSON.stringify(complexMessage));
```

A filter can be applied to all incoming messages to handle the decoding of data.

```javascript
channel.filter(function(m){
  return JSON.parse(m);
});
```

Or if not all messages need to be complex objects then perhaps multiple channels should be used.

```javascript
simpleChan = $shove.channel("channel-a");
complexChan = $shove.channel("channel-b");

simpleChan.on("message",function(message,from){
  // handle incoming simple (string) messages
  console.log(typeof message);
});

complexChan.on("message",function(message,from){
  // handle incoming object messages
  console.log(typeof message);
})

simpleChan.publish("simple messages abound!");

complexChan.filter(function(m){
  return JSON.parse(m);
});
complexChan.publish(JSON.stringify({x:0,y:100,l:42}));
```

If publishing messages is denied, the user can request authorization on any given channel.  The `channel-key` shall be provided by the client application.  See the [Channel Keys](https://github.com/shove/shove-ruby#channel_keys "Shove-Ruby:Channel Keys") section of the [shove-ruby](https://github.com/shove/shove-ruby "Shove-Ruby") implementation.

```javascript
channel.authorize('channel-key');
channel.on('publish_granted',function(){
  console.log('publishing on channel:' + channel.name + ' has been granted');
  // start sending messages or process a queue of messages
});
```