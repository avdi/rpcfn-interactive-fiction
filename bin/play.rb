#!/usr/bin/env ruby
require 'pathname'
require 'strscan'
require 'English'
require 'logger'
require 'forwardable'
require 'set'

class Game
  extend Forwardable

  class << self
    def log(message)
      logger.debug(message)
    end
    
    def logger
      @logger ||= begin
                    l = Logger.new($stderr)
                    l.level = Logger::INFO
                    l
                  end
    end
  end
    

  attr_reader :story, :input, :output, :player_inventory, :blackboard

  def_delegators :story, :synonyms, :object, :actions
  def_delegator :player_location, :objects, :objects_here

  def initialize(story_path, options={})
    @story_path       = Pathname(story_path)
    Game.log "Loading story from #{@story_path}"
    @story            = Story.load(@story_path.read)
    @input            = options.fetch(:input) { $stdin }
    @output           = options.fetch(:output) { $stdout }
    @ended            = false
    @player_room_name = :unset
    @player_inventory = Set.new
    @blackboard       = {}
    @logger           = options.fetch(:logger) { lambda{} }
  end

  def play!
    start!
    execute_one_command! until ended?
  end

  def start!
    @ended            = false
    @player_room_name = @story.starting_room
    Game.log "Starting player in #{@player_room_name}"
    say_location
  end

  def execute_one_command!
    command = expand_synonyms(@input.readline.strip.downcase)
    Game.log "Command: #{command}"
    case command
    when "q", "quit"
      ended!
    when "look", "l"
      say_location(true)
    when "inventory", "i"
      say_inventory
    when /^(get|take|pick up)\s+(.*)$/
      pick_up_object!($2)
    when /^(drop|put down)\s+(.*)$/
      drop_object!($2)
    when *story.exits
      move_player!(command) and say_location
    when *actions.keys
      message, blackboard = safe_eval(actions[command].code)
      if message then say message end
      if blackboard && blackboard.is_a?(Hash)
        self.blackboard.merge!(blackboard)
      end
    else
      say "I don't know that word."
    end
  end

  # check if the player is in the given room ID
  def player_in?(room)
    @player_room_name == room
  end

  # check to see if player has the given item ID in inventory
  def player_has?(object)
    player_inventory.include?(object)
  end

  def ended?
    @ended
  end

  def ended!
    @ended = true
  end

  def move_player!(direction)
    new_room = player_location.exits.fetch(direction) do
      output.puts "There is no way to go in that direction."
      Game.log "Valid exits: #{player_location.exits.inspect}"
      return false
    end
    if guard = player_location.exit_guards[direction]
      allowed, message = safe_eval(guard)
      Game.log "Guard result: #{allowed.inspect}, #{message.inspect}"
      if !allowed
        say message
        return false
      end
    end
    @player_room_name = new_room
    Game.log "Now in #{new_room}: #{player_location.inspect}"
    true
  end

  def pick_up_object!(name)    
    Game.log "Picking up #{name}"
    identifier = name.to_s
    if objects_here.include?(identifier)
      player_inventory << identifier
      objects_here.delete(identifier)
      say "OK"
      true
    else
      say "I see no #{name} here"
      false
    end
  end

  def drop_object!(name)
    Game.log "Dropping #{name}"
    identifier = name.to_s
    if player_inventory.include?(identifier)
      objects_here << identifier
      player_inventory.delete(identifier)
      say "OK"
      true
    else
      say "I see no #{name} here"
      false
    end
  end

  def player_location
    story.rooms.fetch(@player_room_name) do
      raise "Invalid location #{@player_room_name}"
    end
  end

  private

  def say(*args)
    output.puts(*args)
  end


  def say_location(full=false)
    if player_location.visited? && !full
      say "You're " + player_location.title + "."
    else
      say player_location.description
    end
    player_location.objects.each do |object_name|
      say object(object_name).description
    end
    player_location.visited = true
  end

  def say_inventory
    if player_inventory.empty?
      say "You're not carrying anything"
    else
      say "You are currently holding the following:"
      player_inventory.each do |object_name|
        say object(object_name).title
      end
    end
  end

  def expand_synonyms(command)
    # Try longest term matches first
    synonyms.keys.sort_by{|s| s.size}.reverse.each do |synonym|
      term = synonyms[synonym]
      # The FNORDs are to prevent double-substitution
      command = command.gsub(/\b#{synonym}\b/, "FNORD#{term}FNORD")
    end
    command.gsub("FNORD", "")
  end

  def safe_eval(code)
    Game.log "Evaluating #{code}"
    Thread.start do
      $SAFE = 4
      instance_eval(code)
    end.join.value
  end
end

class Story
  def self.load(text)
    story = new(text)
    story.load
    story
  end


  attr_reader :scanner, :starting_room, :rooms, :objects, :synonyms, :actions

  def initialize(text)
    @text          = text
    @scanner       = StringScanner.new(@text)
    @rooms         = {}
    @objects       = {}
    @actions       = {}
    @starting_room = :unset
    @synonyms      = {}
  end

  # Load a Story from the provided text
  def load
    while scanner.scan_until(/^(Room|Object|Synonyms|Action)(\s+([@$!]\w+))?:\s*\n/)
      type       = scanner[1]
      identifier = scanner[3]
      Game.log "Processing #{type} definition for #{identifier}"
      case type
      when "Room"   then add_room!(identifier)
      when "Object" then add_object!(identifier)
      when "Synonyms" then scan_synonyms!
      when "Action" then add_action!(identifier)
      else raise "Unrecognized definition of '#{type}'"
      end
    end
  end

  def add_room!(identifier)
    Game.log "Adding room #{identifier}"
    @starting_room = identifier if @starting_room == :unset
    room = Room.new
    scan_attributes! do |attribute|
      case attribute
      when "Title"
        room.title = scanner.scan_until(/\n/).strip
        Game.log "Set room #{identifier} title to #{room.title}"
      when "Description"
        room.description = scan_description!
        Game.log "Set room #{identifier} description to #{room.description}"
      when "Exits"
        scan_exits! do |direction, target_room, guard|
          room.exits[direction] = target_room
          room.exit_guards[direction] = guard
          Game.log "Added #{identifier} exit #{direction} to #{target_room}"
        end
      when "Objects"
        scan_objects! do |object|
          room.objects << object
          Game.log "Added object #{object} to #{identifier}"
        end
      else raise "Unrecognized attribute '#{attribute}'"
      end
    end
    rooms[identifier] = room
  end

  def add_object!(identifier)
    object = GameObject.new
    scan_attributes! do |attribute|
      case attribute
      when "Terms"
        object.terms = scan_terms!
        object.title = object.terms.first
        object.terms.each do |term|
          synonyms[term.downcase] = identifier
        end
        Game.log "Set #{identifier} title: #{object.title}"
      when "Description"
        object.description = scanner.scan_until(/\n/).strip
        Game.log "Set #{identifier} desc: #{object.description}"
      else raise "Unrecognized attribute '#{attribute}'"
      end
    end
    objects[identifier] = object
  end

  def add_action!(identifier)
    Game.log "Adding action #{identifier}"
    action = Action.new
    scan_attributes! do |attribute|
      case attribute
      when "Terms" then 
        action.terms = scan_terms!
        action.terms.each do |term|
          synonyms[term.downcase] = identifier
        end
      when "Code" 
        action.code = scan_code!
        Game.log "Code for action #{identifier}: #{action.code}"
      else raise "Unrecognized attribute '#{attribute}'"
      end
    end
    self.actions[identifier] = action
  end

  def scan_synonyms!
    while scanner.scan(/\s+(\w+):(.*)\n/)
      word     = scanner[1]
      synonyms = scanner[2].strip.split(/\s*,\s*/)
      Game.log "Adding synonyms for #{word}: #{synonyms.inspect}"
      synonyms.each do |syn| self.synonyms[syn] = word end
    end
  end

  def scan_description!
    next_line!
    description = ""
    description << scanner.matched while scanner.scan(/^    .*\n/)
    description.tr_s!(" \t\n", " ").strip!
    description
  end

  def scan_terms!
    scanner.scan_until(/\n/).strip.split(/\s*,\s*/)
  end

  def scan_code!
    if scanner.scan(/\s*\{\{\{(.*?)\}\}\}/m)
      code = scanner[1]
      scanner.scan_until(/\n/)
    end
    code
  end

  def scan_exits!
    next_line!
    while scanner.scan(/\s+(\w+)\s+to\s+(@\w+)(\s+guarded by:)?/)
      direction = scanner[1]
      target    = scanner[2]
      guarded   = !!scanner[3]
      guard = if guarded
                scan_code!
              else
                scanner.scan_until(/\n/)
                nil
              end
      Game.log "Exit guard for #{direction}->#{target} is #{guard}"
      yield direction, target, guard
    end
  end

  def scan_objects!
    next_line!
    while scanner.scan(/\s+(\$\w+).*\n/)
      yield scanner[1]
    end
  end

  def exits
    rooms.inject([]){|exits, (room_id, room)| 
      exits.concat(room.exits.keys)
    }
  end

  def object(name)
    objects.fetch(name) do raise "No such object: #{name}" end
  end

  private

  def next_line!
    scanner.scan_until(/\n/)
  end

  def scan_attributes!
    while scanner.scan(/  ([A-Z]\w+):/)
      yield scanner[1]
    end
  end
end

class Room < Struct.new(:title, :description, :exits, :exit_guards, :objects, :visited)
  def initialize(*args)
    super(*args)
    self.exits       ||= {}
    self.exit_guards ||= {}
    self.objects     ||= Set.new
    self.visited     ||= false
  end

  def visited?
    visited
  end
end

class GameObject < Struct.new(:title, :description, :terms)
end

class Action < Struct.new(:terms, :code)
end

if $PROGRAM_NAME == __FILE__
  if ARGV.delete('-d') || ARGV.delete('--debug')
    Game.logger.level = Logger::DEBUG
    Game.log "Debug mode enabled"
  end
  story_path = ARGV[0]
  unless story_path
    warn "Usage: #{$PROGRAM_NAME} STORY_FILE"
    exit 1
  end
  game = Game.new(story_path)
  game.play!
end
