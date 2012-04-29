$(function() {

  log("starting shove integration test")

  log("trying to connect")

  $shove.connect("test", {
    hosts: ["shove.dev:9000"]
  });

  $shove.authenticate("test");

  $shove.on("connect", function() {
    log("connected");
  });

  $shove.on("disconnect", function() {
    log("disconnected");
  });

  $shove.on("failure", function() {
    log("failure");
  });

  $shove.on("handshaking", function() {
    log("handshaking");
  });

  $shove.on("authorize", function() {
    log("authorized");
  });

  $shove.on("authorize_denied", function() {
    log("authorize denied");
  });

  $shove.on("reconnect", function() {
    log("reconnect");
  });

  var channel = $shove.channel("integration_test");

  channel.on("subscribing", function() {
    log("subscribing");
  });

  channel.on("subscribe", function() {
    log("subscribed");
  });

  channel.on("unsubscribing", function() {
    log("unsubscribing");
  });

  channel.on("unsubscribe", function() {
    log("unsubscribed");
  });

  channel.on("subscribe_denied", function() {
    log("subscribe denied");
  });

  channel.on("publish_granted", function() {
    log("publish granted");
  });

  channel.on("publish_denied", function() {
    log("publish denied");
  });

  channel.on("message", function(m) {
    log("message: " + m);
  });

  channel.publish("hello self!");

});