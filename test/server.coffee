# Don't get too excited, this is not a real test!

connect = require 'connect'

ObjectSync = require '../lib/object-sync'

server = connect.createServer()

id_counter = 1

# local object database
objects = {}
object_owners = {}


sync = ObjectSync.listen server, 
  destroy: (id, sid, callback) ->
    if not objects[id]
      return callback
        code: 'invalid_id'
    delete objects[id]
    if object_owners[sid]
      idx = object_owners[sid].indexOf id
      object_owners[sid].splice idx, 1 if idx isnt -1
      delete object_owners[sid] if not object_owners[sid].length
    callback null
    
  update: (obj, sid, callback) ->
    if objects[obj.id]
      same = true
      for prop, val of obj when objects[obj.id][prop] isnt val
        same = false
        objects[obj.id][prop] = val
      callback null, objects[obj.id], not same
    else callback
      code: 'invalid_id'
      
  create: (obj, sid, callback) ->
    obj.id = id_counter++
    objects[obj.id] = obj

    object_owners[sid] or= []
    object_owners[sid].push obj.id

    callback null, obj
    
  fetch: (ids, sid, callback) ->
    results = []
    for id in ids
      results.push (objects[id] or null)
    callback null, results


# remove all objects the disconnecting player created
sync.on 'disconnect', (sid) ->
  if object_owners[sid]
    ids = [].concat(object_owners[sid])
    sync.destroy id for id in ids

# serve list of of game objects to new clients
server.use '/init', (req, res, next) ->
  keys = Object.keys objects
  response = JSON.stringify keys
  headers =
    'Content-Type': 'application/json; charset=utf-8'
    'Content-Length': Buffer.byteLength response
  res.writeHead 200, headers
  res.end response
  

server.use '/coffee', connect.compiler
  src: './static/coffee'
  enable: ['coffeescript']

server.use '/', connect.staticProvider './static'
server.listen 80
module.exports = server