# Shove.io Javascript Client

This is the javascript client library for shove.io, the SaaS for web push.  Hosting your own version of the script is not supported
since the javascript is modified with cluster information on request.  You can, however, look here if you are curious.

For a full overview of the client and instructions on how to use it,
please check out the [shove.io javascript documentation](http://shove.io/documentation/javascript_api)

## Include the Shove Library

Include the latest stable version of the shove javascript client.

```html
<script type="text/javascript" src="http://cdn.shove.io/shove.js"></script>
```

## Connect to an App Network

### Connect

Connect the client to your app's network to enable the client to publish or receive messages from the app and perhaps other clients.

```javascript
$shove.connect('test-network');
```

### Bind handlers to shove app networks

Allow your client-side app to respond to network connection events with the following types:

+ connecting
+ connect
+ disconnect
+ authorize
+ reconnect

```javascript
$shove.on('connect',function(){
  window.alert('shove network connected');
  return;
});
$shove.on('authorize',function(){
  window.alert('shove network authorized, feel free to publish to all channels');
  return;
});
```

### Subscribe to an App's Channel

Channels that do not exist will be created automatically by the Shove server.  Bind handlers using the following event types:

+ message
+ subscribing
+ subscribe
+ unsubscribing
+ unsubscribe
+ unauthorized

```javascript
channel = $shove.channel('test-channel');
channel.subscribe();
channel.on('subscribe',function(){
  window.alert('you are subscribed to this channel!');
  return;
});
channel.on('unauthorized',function(){
  window.alert('channel subscribed failed, not authorized!');
  return;
});
```

### Unsubscribe from Channels

A client will cease to receive messages from a channel when unsubscribed.

```javascript
channel.unsubscribe();
```

#### Add filters to easily modify incoming messages

Filters are applied to incoming messages before the 'message' event is fired.  Message processing can be halted if a filter returns `false`.

```javascript
/* Filter replaces occurrences of 'hello' with 'HULLO' within message data strings */
channel.filter(function(msg){
  if(msg.hasOwnProperty('data') && typeof msg.data == 'string'){
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

### Self Authorize

In some cases it may be beneficial to have a client authorized to publish on all channels, perhaps a private version of the client not open to the public.  Supplying an `app_key` and using the `authorize` method will grant full publishing permissions on all channels for the client.  Channels will still have to be subscribed to individually.

```javascript
$shove.app_key = 'test-network-app-key';
$shove.authorize();
```

#### Publish Messages

Messages can be simple strings or numbers or even complex objects and arrays.

```javascript
channel.publish('message here');
channel.publish({
  foo:'bar',
  arr:[4,5,6]
});
```