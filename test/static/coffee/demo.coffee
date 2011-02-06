sync = new ObjectSync()

me = null
$talk = $('#talk')
$input = $talk.find('input')
mePlayer = -> $(".player_#{me}").data('player')

showTalk = ->
  if not $talk.is(':visible')
    $talk.show()
    $input.focus()

submitTalk = ->
  return unless $talk.is(':visible')
  new_say = $('#talk input').val()
  return if new_say is ''
  hideTalk()
  player = mePlayer()
  player.says = new_say
  sync.save player, (err) ->
    console.error err if err

hideTalk = ->  
  $talk.fadeOut('fast')
  $input.val('').blur()
  
installHandlers = ->
  arrow = {left: 37, up: 38, right: 39, down: 40}
  $(window).keydown (e) ->
    key = e.keyCode or e.which
    player =
      id: mePlayer().id
    switch key
      when arrow.up
        player.y -= 10
        sync.save player
      when arrow.right
        player.x += 10
        sync.save player
      when arrow.down
        player.y += 10
        sync.save player
      when arrow.left
        player.x -= 10
        sync.save player
      else
        showTalk()

  $(window).keyup (e) ->
    key = e.keyCode or e.which
    switch key
      when arrow.left, arrow.right, arrow.up, arrow.down
        return
      when 13 # return
        submitTalk()
      when 27 # esc
        hideTalk()
    

clear = ->
  $('.player').remove()
  me = null
  

drawPlayer = (player) ->
  # is that player already on the screen?
  $player = $(".player_#{player.id}")
  if not $player.length
    $player = $('<div>')
        .addClass('player')
        .addClass("player_#{player.id}")
        .append($('<div class="says"></div>'))
        .append($('<div class="avatar avatar_'+player.avatar_type+'"></div>'))
        .appendTo('body')
    if player.id is me
      $player.addClass('me')
  $player.data 'player', player
  $player.css
    top: player.y
    left: player.x
  $says = $player.find('.says')
  old_says = $says.text()
  if player.says isnt old_says
    $says.hide().fadeIn().text player.says

removePlayer = (id) ->
  $(".player_#{id}").fadeOut -> $(@).remove()


initialize = ->
  
  $.getJSON '/init', (result) ->
    sync.fetch result, (err, objects) ->
      if err
        console.error err
        return alert('boo, that didnt work')
      for player in objects
        drawPlayer player

createPlayer = ->

  player =
    x: Math.floor(Math.random()*400) + 11
    y: Math.floor(Math.random()*300) + 71
    says: "I'm new here, talk to me"
    avatar_type: Math.floor(Math.random()*5) + 1
  
  sync.save player, (err, player) ->
    if err
      console.error err
      return alert 'Awwwww. no. *dies*'
    me = player.id

$ ->

  sync.connect()

  sync.on 'create', (obj) -> drawPlayer obj
  sync.on 'update', (obj) -> drawPlayer obj
  sync.on 'destroy', (id) -> removePlayer id

  sync.on 'connect', ->
    clear()
    initialize()
    installHandlers()
    createPlayer()

  window.sync = sync

