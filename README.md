node-object-sync
================

node-object-sync makes 

This is the first cut implementation that I decided to make. While there's still a lot to do, 

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

Note: All examples and the implementation are in [coffee-script](http://jashkenas.github.com/coffee-script/). CoffeeScript is great and you should probably use it. If you don't want to use CoffeeScript, you can easily convert it using the 'Try CoffeeScript' button on the aforementioned website.

***On the server***

[[gist.github.com/813251]]

***On the client***

    The client will automatically reconnect if the server connection dies. For a more detailed, runnable example check out the test/ directory.

[[gist.github.com/813250]]
    

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
 
***Most importantly, the design of this software shall be such that all the above TODOs can be implemented in the application layer***


License
=======

I haven't really made up my mind yet. Any reason not to go with MIT?

(c) 2011 Jonas Huckestein