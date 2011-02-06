socket_io = require 'socket.io'
EventEmitter = require('events').EventEmitter


class ObjectSync extends EventEmitter
  
  
  # Wraps a server and returnes ObjectSync object.
  @listen: (http_server, options={}) ->
    options.server = http_server
    sync = new ObjectSync options
    sync.listen()
    return sync
  
  constructor: (options) ->
    super()
    @options =
      server:  null
      update:  => @log 'missing update handler', arguments[0]
      create:  => @log 'missing create handler', arguments[0]
      destroy: => @log 'missing destroy handler', arguments[0]
      fetch:   => @log 'missing fetch handler', arguments[0]
    
    for key, val of options
      @options[key] = val

    for action in ['update', 'create', 'destroy', 'fetch']
      @setHandler action, @options[action]
  
  # Starts listening on the wrapped server. If no server was passed
  # a new socket.io server is created
  # 
  # TODO: remove dependency on HTTP server
  listen: ->
    throw new Error 'No server in options!' unless @options.server

    @log 'hooking up to server. booyah.'
    @_socket = socket_io.listen @options.server

    @_socket.on 'clientConnect', @_onConnect

    @_socket.on 'clientMessage', @_onMessage
    
    @_socket.on 'clientDisconnect', @_onDisconnect

  save: (obj, cb) ->
    if obj.id then @_update obj, 0, (cb or ->)
    else @_create obj, 0, (cb or ->)
  destroy: (id,  cb) -> @_destroy id, 0, (cb or ->)
  fetch: (ids, cb) -> @_fetch ids, 0, (cb or ->)

  # Message =
  #   type: 'save' or 'destroy' or 'fetch'
  #   obj: the object to save
  #   id: the ids  to destroy/fetch
  #   client_req_id: id the client uses to reference this request for cb
  # If the object has no id, it will be created, otherwise updated
  _onMessage: (msg, client) =>
    if not (typeof client is 'object' and msg.type and msg.client_req_id)
      return @log new Error('invalid message received'), arguments
    
    # construct cb function that will respond directly to the client
    # TODO obfuscate stack trace
    client_cb = (err, result) =>
      response =
        code: 'ok'
        result: result
        type: 'response'
        client_req_id: msg.client_req_id
      if err
        response.code = 'error'
        response.error = err
      client.send response
    
    switch msg.type
      when 'save'
        if typeof msg.obj.id is 'undefined'
          @_create msg.obj, client, client_cb
        else @_update msg.obj, client, client_cb
      when 'destroy'
        @_destroy msg.id, client, client_cb
      when 'fetch'
        @_fetch msg.id, client, client_cb
      
  _onDisconnect: (client) =>
    @emit 'disconnect', client.sessionId

  _onConnect: (client) =>
    @emit 'connect', client.sessionId

  _broadcast: (payload) ->
    response =
      code: 'ok'
    for key, val of payload
      response[key] = val

    @_socket.broadcast response
    
    
  _fetch: (ids, client, client_cb) =>
    @_handle 'fetch', [ids, client.sessionId], client_cb

  _destroy: (id, client, client_cb) =>
    @_handle 'destroy', [id, client.sessionId], (err, fire_event=true) =>
      client_cb arguments...
      if fire_event and not err
        @_broadcast
          type: 'destroy'
          id: id

  _create: (obj, client, client_cb) =>
    @_handle 'create', [obj, client.sessionId], (err, obj, fire_event=true) =>
      client_cb arguments...
      if fire_event and not err
        @_broadcast 
          type: 'create'
          obj: obj
      
  _update: (obj, client, client_cb) =>
    @_handle 'update', [obj, client.sessionId], (err, obj, fire_event=true) =>
      client_cb arguments...
      if fire_event and not err
        @_broadcast
          type: 'update'
          obj: obj
    
    

  # Sets the function to handle event of type ev. Possible event types
  # are fetch, create, update, destroy.
  # 
  # Parameters for handlers: create and update take an object and destroy
  # and fetch take an id. All handlers take a callback as last param.
  setHandler: (ev, handler) ->
    @_handlers or= {}
    @_handlers[ev] = handler

  _handle: (ev, args, cb) ->
    #try
      @_handlers[ev](args..., cb)
    #catch e
    #  cb e
  log: ->
    console.log arguments...

  

module.exports = ObjectSync