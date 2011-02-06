node-object-sync
================

node-object-sync transparently synchronizes objects across multiple connected clients. It's a low-level library that aims to take the pain out of synchronizing state across clients.

Many webapps and games offer a 'multiplayer' components (for webapps that would be called collaboration or social feature). Many such apps use socket.io for realtime communication and some other framework on top of that to manage models (views, controllers and whatever else). Oftentimes the glue between model-land and socket.io on the client and socket.io and the database on the server is a bunch of complicated custom code. node-object-sync is an attempt to replace that code with something more generic.

This is the first cut implementation. While there's still a lot to do, I thing this is already pretty useful. Check out the test directory for a little game that that has surprisingly little multiplayer networking code :)

Note: All examples and the implementation are in [coffee-script](http://jashkenas.github.com/coffee-script/). CoffeeScript is great and you should probably use it. If you don't want to use CoffeeScript, you can easily convert it using the 'Try CoffeeScript' button on the aforementioned website.

***Any contributions are more than welcome***

Design Notes
============

node-object-sync allows you to maintain a consistent world state across a number of connected clients. If you modify an object locally, that change will transparently propagate to all connected clients.

node-object-sync is designed to be a low-level library that belongs *underneath* your model layer. It doesn't (yet) deal with model types, atomic edits and other complicated stuff. The intention is that you can slip this in underneath frameworks like [backbone.js](http://github.com/documentcloud/backbone) or [javascriptmvc](http://github.com/jupiterjs/javascriptmvc).

As far as node-object-sync is concerned, an entity has a unique id and arbitrary properties. There's nothing more to it. There is currently no support for collection types (lists, sets, maps). If you want to have different model classes, you can namespace your ids.

Here's a list of bullet points:

 * Models destroy, update and create events appear transparently across all clients
 * Objects consist of an id and arbitrary primitive properties
 * Create events are only ever fired on the client if that client is connected when the object was created
 * socket.io is used for all communication
 * When changing objects, the client can pass a callback that gets executed after a response for that request has come through. In addition to that update, create and destroy events will fire.
 * Is database agnostic on the server side. You can even not use any database at all (use it to sync in-session objects among multiple clients)

TL;DR show me some code
======================

***On the server***

    ObjectSync = require 'object-sync'
    server = http.createServer()

    # Hook an ObjectSync instance up to our server.
    # Define a bunch of handlers for CRUD events. The handlers are
    # async because they'll likely interact with some kind of database
    sync = ObjectSync.listen server, 

      # a client wants to delete object with id id
      destroy: (id, client_sid, callback) ->
        console.log "client #{client_sid} has destroyed object #{id}"
        callback null # sends events to clients

      # a client wants to update an object
      update: (obj, client_sid, callback) ->
        # sends an error to the client requesting the update and no
        # message to all other clients
        callback
          code: 'invalid_id'

      # a client wants to create an object
      create: (obj, client_sid, callback) ->
        callback null, obj

      # a client requests a list of objects
      fetch: (ids, client_sid, callback) ->
        results = [] # ...
        callback null, results

    # The following functions let the server pro-actively change things
    sync.save obj, (err, obj) -> # ...
    sync.destroy obj, (err, obj) -> # ...
    sync.fetch ids, (err, objs) -> # ...
    sync.update obj, (err, obj) -> # ...

***On the client***

    The client will automatically reconnect if the server connection dies. For a more detailed, runnable example check out the test/ directory.

    <script src="socket.io/socket.io.js"></script> 
    <script src="/coffee/object-sync-client.js"></script> 
    <script>
        sync = new ObjectSync();
        sync.connect();
        sync.on('update', function(obj) {
            switch(obj.type) {
                case 'player':
                    drawPlayer(obj);
                    break;
                case 'score':
                    updateScore(obj);
                    break;
                // ... etc
            }
        });
        sync.on('destroy', function(id){/*...*/});
        sync.on('create', function(obj){/*...*/});

        # Create a new object (saving something without an id)
        sync.save({
            is_this_new: 'yes'
        }, function(err, obj) {
            // returns either an error or a server-provided object
            // if there was no error, a 'create' event will fire here
            // and on every other connected client
        });
        sync.save({
            id: 5,
            is_this_new: false,
            is_this_updated: true
        }, function(err, obj){
            // updates an object
        });
        sync.fetch([1,2,3,4], function(err, results) {
            // fetches objects 1,2,3 and 4
        });
        sync.destroy(1, function(err) {
            // if there was no error, object 1 is now destroyed
            // a 'destroy' event will fire shortly
        })
        sync.allObjects(); // returns a map of all objects on the client
    </script>
    

TODO:
=====

Some take 5 minutes and some take 5 days.

 * Consider moving a little bit of model layer magic into the client lib. For instance, objects should only be updated if they have actually changed.
 * Don't expose the entire world to every client. Let client's subscribe to objects.
 * Scale the whole shebang to MMORPG levels using RabbitMQ as routing backend
 * Don't use new objects liberally. Use exactly one reference to an object with a certain id and modify it if it changes. This should prevent a few bugs and make an eventual GC routine easier to implement.
 * Let client have different state from global state with eventual consistency and rollbacks (local storage and offline mode FTW)
 * Handle collection properties (lists, sets)
 * Pass around diffs instead of full objectsto save bandwidth and make my life more complicated
 * Let servers talk to one another (aka make the server a full-size client)
 * Handle timeouts, crashes and other crazies
 * Perhaps support rigid JSON schemas (diffs will be flimsy to do otherwise)
 * Figure out how to deal with atomic counters. What if two clients change a value at the same time?
 * What if not all objects are visible in the same way to all clients?
 * Deal with custom socket.io endpoints (trivial)
 * Buffer communication for N minutes and resend all communication if clients drop for a little bit.
 * buffer requests on client if disconnected
 * Don't use /socket.io endpoint by default
 * Serve client files from server
 

License
=======

I haven't really made up my mind yet. Any reason not to go with MIT?

(c) 2011 Jonas Huckestein