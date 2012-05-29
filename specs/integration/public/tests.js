function log(message) {
  $("#log").append($("<div></div>").html(message));
}

$(function() {

  log("starting shove integration test")

  log("trying to connect")

  $shove.debug(true);

  $shove.connect("test", "dee1baefd3a449474cbc9817929ebc3019eaece5", {
    hosts: ["localhost:9000"]
  });

  $shove.channel("*").authenticate("06188df7659636e44c0f788fb21da049027fde88");

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

  var channel = $shove.channel("presence:integration_test");

  channel.on("presence_added", function(from) {
    log("user joined: " + from);
  });

  channel.on("presence_removed", function(from) {
    log("user left: " + from);
  });

  channel.on("presence_list", function(list) {
    log("current users: " + list.length);
  });

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

  channel.on("message", function(m, from) {
    log("message: " + m + " from: " + from);
  });

  $("#clicky").click(function() {
    $("#log").empty();
    for(var i = 0;i < 100;i++) {
      channel.publish("test: " + i);
    }
  });

});