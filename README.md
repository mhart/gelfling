# GELF (Graylog2) messages in node.js

Includes chunked messages, so messages can be any size
(couldn't find another node.js lib that does this)

```javascript
var gelfling = require('gelfling')

var client = gelfling()

client.send('Message', function(err) { console.log('Sent') })

client.send({ short_message: 'Message', facility: 'myApp', level: gelfling.INFO })

var complexClient = gelfling('localhost', 12201, {
  defaults: {
    facility: 'myApp',
    level: gelfling.INFO,
    short_message: function(msg) { var txt = msg.txt; delete msg.txt; return txt }
    myAvg: function(msg) { return msg.myTotal / msg.myCount }
  }
})

complexClient.send({ txt: 'Hi', myTotal: 1337, myCount: 23 })
```

Passing the option `{tcp: true}` establishes a TCP connection with the
given `host` and `port`. Whenever a message is written to a
TCP-enabled gelfling object it will attempt to establish a connection
if one isn't already open. If the connection fails, however, the send
is not retried. Error handling is up to you. Connection errors are
passed to the `send` callback.

Gzipping is disabled with TCP because it isn't supported properly by
graylog. TCP GELF messages are NUL-delimited, and the gzip stream
contains NULs, which confuses the server.

For more information on TCP GELF and Gzip, see:
* https://github.com/Moocar/logback-gelf#tcp
* https://github.com/Graylog2/graylog2-server/issues/127
* https://github.com/t0xa/gelfj/pull/61
