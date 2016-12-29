_ = require 'lodash'

log =
  v: console.log.bind(console)

stack = ( ->
  commands = []
  position = -1
  groupCount = []
  count = 0
  commandsMax = 1000
  undoing = false
  currentSelectionIndex = 0

  debounceGroupCount = _.debounce ->
    for i in [position-count+1..position]
      groupCount[i] = count
    count = 0
  , 17

  increaseCount = ->
    position++
    count++
    groupCount[position] = 1
    debounceGroupCount()

  updateSelectionIndex = (selectionIndex) ->
    currentSelectionIndex = selectionIndex

  repeatUndo = (callback) ->
    for i in [1..groupCount[position]]
      callback(commands[position--])

  repeatRedo = (callback) ->
    for i in [1..groupCount[position + 1]]
      callback(commands[++position])

  runBinding = (command, fn) ->
    command[fn].bind(command.self)(command.bundle, command.bundleDeep) if command[fn]

  clearRedo = ->
    groupCount.splice(position + 1, groupCount.length)
    commands.splice(position + 1, commands.length)
  isFull = ->
    position >= commandsMax
  popFront = ->
    for i in [1..groupCount[0]]
      commands.shift()
      position--
    groupCount.splice(0, 1)
  clear = ->
    commands = []
    position = -1
    groupCount = []
    count = 0
    currentSelectionIndex = 0

  push = (command) ->
    if history.enabled
      clearRedo()
      if isFull()
        popFront()
        # TODO: Show full messsage popup
      command.selectionIndex = currentSelectionIndex
      commands.push(command)

  execute = (command) ->
    push(command)
    log.v '[history]execute:', command.type, command.subtype
    increaseCount()
    runBinding(command, 'beforeEach')
    runBinding(command, 'beforeRedo')
    runBinding(command, 'redo')
    runBinding(command, 'afterRedo')
    runBinding(command, 'afterEach')

  save = (command) ->
    push(command)
    increaseCount()

  canUndo = ->
    position >= 0

  canRedo = ->
    position < commands.length - 1

  undo = ->
    return unless history.enabled
    return unless canUndo()
    undoing = true
    index = currentSelectionIndex
    beforeAll()
    repeatUndo (command) ->
      log.v '[history]undo:', command.type, command.subtype
      runBinding(command, 'beforeEach')
      runBinding(command, 'beforeUndo')
      runBinding(command, 'undo')
      runBinding(command, 'afterUndo')
      runBinding(command, 'afterEach')
      index = command.selectionIndex
    afterAll(index)
    updateSelectionIndex(index)
    undoing = false

  redo = ->
    return unless history.enabled
    return unless canRedo()
    if undoing
      log.e 'Redo happens even undo is not finished yet!'
      console.trace()
    index = currentSelectionIndex
    beforeAll()
    repeatRedo (command) ->
      log.v '[history]redo:', command.type, command.subtype
      runBinding(command, 'beforeEach')
      runBinding(command, 'beforeRedo')
      runBinding(command, 'redo')
      runBinding(command, 'afterRedo')
      runBinding(command, 'afterEach')
      index = command.selectionIndex
    afterAll(index)
    updateSelectionIndex(index)

  beforeAll = ->

  afterAll = (selectionIndex) ->

  return {
    _: # called by command
      save: save  # save command except excution
      execute: execute # save and excute command
      clear: clear
      selectionChanged: ->
        currentSelectionIndex++
    public:
      canUndo: canUndo
      canRedo: canRedo
      undo: undo
      redo: redo
  }
)()

command =
  create: (type, subtype, self, bundle, bundleDeep, fns) ->
    unless subtype
      subtype = ''
    command = new Command type, subtype, self, bundle, bundleDeep
    for key, fn of fns
      command[key] = fn
    log.v '[history]command created:', command.type, command.subtype
    command

class Command
  constructor: (@type, @subtype, @self, @bundle, bundleDeep) ->
    if bundleDeep then @bundleDeep = _.cloneDeep bundleDeep
  execute: ->
    stack._.execute(this)
  save: ->
    stack._.save(this)

  #overriden
  redo: ->
  undo: ->

  # options
  #beforeUndo: ->
  #afterUndo: ->
  #beforeRedo: ->
  #afterRedo: ->
  #beforeEach: -> # run before both
  #afterEach: -> # run after both

module.exports = history =
  stack: stack.public
  undo: ->
    stack.public.undo()
  redo: ->
    stack.public.redo()
  selectionChanged: ->
    stack._.selectionChanged()
  command: command
  enabled: true
  enable: ->
    @enabled = true
  disable: ->
    @enabled = false
  destroy: ->
    stack._.clear()

