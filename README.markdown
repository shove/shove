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
```
channel = $shove.channel('test-channel');
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