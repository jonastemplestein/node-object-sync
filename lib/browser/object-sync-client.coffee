window.console or= {}
console.log or= ->
console.error or= ->
console.trace or= ->
console.dir or= ->

if not Array.indexOf
  Array.prototype.indexOf = (obj) ->
    for i in [0..@length]
      if this[i] is obj
        return i
    return -1

isArray = Array.isArray or (obj) ->
  obj.constructor.toString().indexOf("Array") isnt -1

default_max_listeners = 10
class EventEmitter
  
  setMaxListeners: (n) ->
    @_events.maxListeners = n
  
  emit: (type) ->
    if type is 'error'
      if not isArray(@_events?.error?) or not @_events?.error.length
        if arguments[1] instanceof Error
          throw arguments[1]
        else throw new Error arguments[1].code
        return false
    
    handler = @_events?[type]
    return false unless @_events?[type]
    
    if typeof handler is 'function'
      switch arguments.length
        # fast cases
        when 1 then handler.call @
        when 2 then handler.call @, arguments[1]
        when 3 then handler.call @, arguments[2]
        else
          args = Array.prototype.slice.call arguments, 1
          handler.apply @, args
      return true
    else if isArrayhandler
      args = Array.prototype.slice.call arguments, 1
      listeners = handler.slice()
      for listener in listeners
        listener.apply this, args
    else
      return false


  addListener: (type, listener) ->
    if typeof listener isnt 'function'
      throw new Error 'addListener only takes instances of Function'

    @_events or= {}
    
    @emit 'newListener', type, listener

    if not @_events[type]
      @_events[type] = listener
    else if isArray(@_events[type])
      if not @_events[type].warned
        m = 0
        if @_events.maxListeners isnt undefined
          m = @_events.maxListeners
        else m = default_max_listeners
        if m and m > 0 and @_events[type].length > m
          @_events[type].warned = true
          console.error "warning: possible EventEmitter memory" + \
              "leak detected. #{@_events[type].length} listeners"
          console.trace()
      @_events[type].push listener
    else
      @_events[type] = [@_events[type], listener]

    return @


  on: EventEmitter.prototype.addListener

  once: (type, listener) ->
    g = =>
      @removeListener type, g
      listener.apply @, arguments
    @on type, g
    return @

  removeListener: (type, listener) ->
    if typeof listener isnt 'function'
      throw new Error 'removeListener only takes instances of Function'
    
    list = @_events?[type]
    return @ unless list
    
    if isArray list
      i = list.indexOf listener
      return @ if i < 0
      list.splice i, 1
      
      if list.length is 0
        delete @_events[type]
    else if @_events[type] is listener
      delete @_events[type]
    return @

  removeAllListeners: (type) ->
    if type and @_events?[type]
      @_events[type] = null
    return this

  listeners: (type) ->
    @_events or= {}
    @_events[type] or= []
    if not isArray @_events[type]
      @_events[type] = [@_events[type]]
    return @_events[type]


# Static functions use a singleton. Instantiate more instances if you want.
class ObjectSync extends EventEmitter
  
  # @getSingleton: (options={}) ->
  #   @_singleton or= new this(options)
  # 
  # @connect: (options) -> @getSingleton().connect arguments...
  # @fetch: (id, cb) -> @getSingleton().fetch arguments...
  # @save: (obj, cb) -> @getSingleton().save arguments...
  # @destroy: (id, cb) -> @getSingleton().destroy arguments...


  constructor: (options={}) ->
    @options =
      auto_reconnect: true
      verbose: false
      reconnect_timeout: 1000

    for key, val of options
      @options[key] = val

    @_socket = new io.Socket
    @_socket.on 'connect', @_onConnect
    @_socket.on 'message', @_onMessage
    @_socket.on 'disconnect', @_onDisconnect

    @_reconnect_timer = null
    @_reconnect_attempts = 0
    @_request_counter = 1
    @_objects = {}
  
  allObjects: -> return @_objects
  
  fetch: (id, cb) ->
    id = [id] if not isArray id
    @_doRequest 'fetch', id, cb

  save: (obj, cb) ->
    @_doRequest 'save', obj, cb

  destroy: (id, cb) ->
    @_doRequest 'destroy', id, cb

  
  # Tries to connect to server until it succeeds
  #
  # TODO implement exponential backoff instead of linear
  connect: ->
    @_reconnect_timer = setTimeout (=>
      if not @_socket.connecting and not @_socket.connected
        @log 'attempting to connect' if @options.verbose
        @_socket.connect() # onConnect will invalidate the timeout
      @connect() if @options.auto_reconnect
    ), @_reconnect_attempts*1000
    @_reconnect_attempts += 1
  
  log: -> console.log arguments... if @options.verbose
  
  isConnected: -> @_socket.connected
  
  _onConnect: =>
    @log 'Connected', arguments if @options.verbose
    # reset some stuff
    @_reconnect_attempts = 0
    clearTimeout @_reconnect_timer
    @_reconnect_timer = null
    @emit 'connect'
  
  _onDisconnect: =>
    @log 'Disconnected', arguments if @options.verbose
    @connect() if @options.auto_reconnect
    @emit 'disconnect'
    
  _onMessage: (payload) =>
    @log 'Message', arguments if @options.verbose
    type = payload.type
    
    error = null
    if payload.code isnt 'ok' then error = payload.error
    result = payload.result
    @emit 'error', error if error
    
    # execute callback in case on is waiting
    @_callReqCallback payload.client_req_id, [error, result]

    # fire local events
    ev_param = payload.obj

    switch type
      when 'destroy'
        ev_param = payload.id
        delete @_objects[payload.id]
      when 'fetch', 'update', 'create'
        @_objects[payload.obj.id] = payload.obj
    @emit type, ev_param unless type is 'response'
        
  
  # TODO buffer requests if disconnected
  _doRequest: (type, obj_or_ids, cb) ->
    payload =
      type: type
      client_req_id: @_request_counter
    if type is 'fetch' or type is 'destroy'
      payload.id = obj_or_ids
    else payload.obj = obj_or_ids
    if typeof cb is 'function'
      @_registerReqCallback @_request_counter, cb
    @_request_counter++
    @_socket.send payload
  
  # TODO count pending cbs to detect leaks
  _registerReqCallback: (req_id, cb) ->
    @_req_callbacks or= {}
    @_req_callbacks[req_id] = cb

  _callReqCallback: (req_id, args) ->
    fn = @_req_callbacks[req_id]
    if typeof fn is 'function'
      fn.apply @, args
    delete @_req_callbacks[req_id]
    
window.ObjectSync = ObjectSync