#!/usr/bin/env ruby
require 'pathname'
require 'strscan'
require 'English'
require 'logger'

class Game
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
    

  attr_reader :story, :input, :output

  def initialize(story_path, options={})
    @story_path       = Pathname(story_path)
    Game.log "Loading story from #{@story_path}"
    @story            = Story.load(@story_path.read)
    @input            = options.fetch(:input) { $stdin }
    @output           = options.fetch(:output) { $stdout }
    @ended            = false
    @player_room_name = :unset
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
    command = @input.readline.strip.downcase
    case command
    when "q", "quit"
      ended!
    when *story.exits
      move_player!(command)
      say_location
    else
      say "I don't know that word."
    end
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
    @player_room_name = new_room
    true
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


  def say_location
    if player_location.visited?
      say "You're " + player_location.title
    else
      say player_location.description
      player_location.visited = true
    end
  end
end

class Story
  def self.load(text)
    story = new(text)
    story.load
    story
  end


  attr_reader :scanner, :starting_room, :rooms, :objects

  def initialize(text)
    @text    = text
    @scanner = StringScanner.new(@text)
    @rooms   = {}
    @objects = {}
    @starting_room = :unset
  end

  # Load a Story from the provided text
  def load
    while scanner.scan_until(/^(Room|Object)\s+([@$]\w+):\s*\n/)
      type       = scanner[1]
      identifier = scanner[2]
      Game.log "Processing #{type} definition for #{identifier}"
      case type
      when "Room"   then add_room!(identifier)
      when "Object" then add_object!(identifier)
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
        scan_exits! do |direction, target_room|
          room.exits[direction] = target_room
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
      when "Title"
        object.title = scanner.scan_until(/\n/).strip
        Game.log "Set #{identifier} title: #{object.title}"
      when "Description"
        object.description = scanner.scan_until(/\n/).strip
        Game.log "Set #{identifier} desc: #{object.description}"
      else raise "Unrecognized attribute '#{attribute}'"
      end
    end
  end

  def scan_description!
    next_line!
    description = ""
    description << scanner.matched while scanner.scan(/^    .*\n/)
    description.tr_s!(" \t\n", " ").strip!
    description
  end

  def scan_exits!
    next_line!
    while scanner.scan(/\s+(\w+)\s+to\s+(@\w+).*\n/)
      direction = scanner[1]
      target    = scanner[2]
      yield direction, target
    end
  end

  def scan_objects!
    next_line!
    while scanner.scan(/\s+($\w+).*\n/)
      yield scanner[1]
    end
  end

  def exits
    rooms.inject([]){|exits, (room_id, room)| 
      exits.concat(room.exits.keys)
    }
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

class Room < Struct.new(:title, :description, :exits, :objects, :visited)
  def initialize(*args)
    super(*args)
    self.exits   ||= {}
    self.objects ||= []
    self.visited ||= false
  end

  def visited?
    visited
  end
end

class GameObject < Struct.new(:title, :description)
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
