# Shove.io Javascript Client

This is the javascript client library for shove.io, the SaaS for web push.  Hosting your own version of the script is not supported
since the javascript is modified with cluster information on request.  You can, however, look here if you are curious.

For a full overview of the client and instructions on how to use it,
please check out the [shove.io javascript documentation](http://shove.io/documentation/javascript_api)


## Connect to an App Network

```
$shove.connect('test-network');
```

### Bind handlers to shove app networks

App network events:

+ connecting
+ connect
+ disconnect
+ authorize
+ reconnect

```
$shove.on('connect',function(){window.alert('shove network connected');});
$shove.on('authorize',function(){window.alert('shove network authorized, feel free to publish to all channels');});
```

### Subscribe to an App's Channel

Channels that do not exist will be created automatically by the Shove server.  Bind handlers using the following event types:

+ message
+ subscribing
+ subscribe
+ unsubscribing
+ unsubscribe
+ unauthorized

```
channel = $shove.channel('test-channel');
channel.on('subscribe',function(){window.alert('you are subscribed to this channel!');});
channel.on('unauthorized',function(){window.alert('channel subscribed failed, not authorized!');});
channel.subscribe();
```

#### Add filters to easily modify incoming messages

Filters are applied to incoming messages before the 'message' event is fired.  Message processing can be halted if a filter returns `false`.

```
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
    if(msg.data.search(/(poop|fanny)/gi) > 0)
      return false;
  }
  return msg;
});

channel.on('message',function(msg){/* present message to user or hand off to client application */return;});
```

### Self Authorize

```
$shove.app_key = 'test-network-app-key';
$shove.authorize();
```

#### Publish Messages

```
channel.publish('message here');
channel.publish({foo:'bar',arr:[4,5,6]});
```

### Unsubscribe from Channels

```
channel.unsubscribe();
```