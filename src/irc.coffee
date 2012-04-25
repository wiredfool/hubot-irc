Robot   = require('hubot').robot()
Adapter = require('hubot').adapter()

Irc     = require 'irc'

class IrcBot extends Adapter
  constructor: (@robot) ->
    super @robot

    @robot.notice = (user, strings...) ->
      @adapter.notice user, strings...

    @robot.Response = IrcResponse

  send: (user, strings...) ->
    for str in strings
      if not str?
        continue
      if user.room
        @robot.logger.info "#{user.room} #{str}"
        @bot.say(user.room, str)
      else
        @robot.logger.info "#{user.name} #{str}"
        @bot.say(user.name, str)

  notice: (user, strings...) ->
    for str in strings
      if not str?
        continue
      if user.room
        @robot.logger.info "notice #{user.room} #{str}"
        @bot.notice(user.room, str)
      else
        @robot.logger.info "notice #{user.name} #{str}"
        @bot.notice(user.name, str)

  reply: (user, strings...) ->
    for str in strings
      @send user, "#{user.name}: #{str}"

  join: (channel) ->
    self = @
    @bot.join channel, () ->
      @robot.logger.info('joined %s', channel)

  part: (channel) ->
    @bot.part channel, () ->
      @robot.logger.info('left %s', channel)

  run: ->
    self = @

    options =
      nick:     process.env.HUBOT_IRC_NICK or @robot.name
      port:     process.env.HUBOT_IRC_PORT
      rooms:    process.env.HUBOT_IRC_ROOMS.split(",")
      server:   process.env.HUBOT_IRC_SERVER
      password: process.env.HUBOT_IRC_PASSWORD
      nickpass: process.env.HUBOT_IRC_NICKSERV_PASSWORD
      fakessl:  process.env.HUBOT_IRC_SERVER_FAKE_SSL?
      unflood:  process.env.HUBOT_IRC_UNFLOOD?
      debug:    process.env.HUBOT_IRC_DEBUG?
      usessl:   process.env.HUBOT_IRC_USESSL?
      userName: process.env.HUBOT_IRC_USERNAME

    client_options =
      userName: options.userName,
      password: options.password,
      debug: options.debug,
      port: options.port,
      stripColors: true,
      secure: options.usessl,
      selfSigned: options.fakessl,
      floodProtection: options.unflood

    client_options['channels'] = options.rooms unless options.nickpass

    bot = new Irc.Client options.server, options.nick, client_options

    next_id = 1
    user_id = {}

    if options.nickpass?
      bot.addListener 'notice', (from, to, text) ->
        if from is 'NickServ' and text.indexOf('registered') isnt -1
          bot.say 'NickServ', "identify #{options.nickpass}"
        else if options.nickpass and from is 'NickServ' and
                (text.indexOf('Password accepted') isnt -1 or
                 text.indexOf('identified') isnt -1)
          for room in options.rooms
            @join room

    bot.addListener 'message', (from, to, message) ->
      @robot.logger.info "From #{from} to #{to}: #{message}"
      
      user = self.userForName from
      unless user?
        id = (new Date().getTime() / 1000).toString().replace('.','')
        user = self.userForId id
        user.name = from

      if to.match(/^[&#]/)
        user.room = to
        @robot.logger.info "#{to} <#{from}> #{message}"
      else
        user.room = null
        @robot.logger.info "msg <#{from}> #{message}"

      self.receive new Robot.TextMessage(user, message)

    bot.addListener 'error', (message) ->
        @robot.logger.error('ERROR: %s: %s', message.command, message.args.join(' '))

    bot.addListener 'pm', (nick, message) ->
        @robot.logger.info('Got private message from %s: %s', nick, message)

    bot.addListener 'join', (channel, who) ->
        @robot.logger.info('%s has joined %s', who, channel)

    bot.addListener 'part', (channel, who, reason) ->
        @robot.logger.info('%s has left %s: %s', who, channel, reason)

    bot.addListener 'kick', (channel, who, _by, reason) ->
        @robot.logger.info('%s was kicked from %s by %s: %s', who, channel, _by, reason)

    bot.addListener 'invite', (channel, from) ->
      @robot.logger.info('%s invite you to join %s', from, channel)
      bot.join channel

    @bot = bot

    self.emit "connected"

class IrcResponse extends Robot.Response
  notice: (strings...) ->
    @robot.adapter.notice @message.user, strings...

exports.use = (robot) ->
  new IrcBot robot

