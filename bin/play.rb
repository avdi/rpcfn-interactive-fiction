#!/usr/bin/env ruby

class Game
  def initialize(story_path, options={})
    @input  = options.fetch(:input)  { $stdin  }
    @output = options.fetch(:output) { $stdout }
  end

  def play!
    start!
    execute_one_command! until ended?
  end

  def start!
    raise NotImplementedError, "Implement me!"
  end

  def execute_one_command!
    raise NotImplementedError, "Implement me!"
  end

  def ended?
    raise NotImplementedError, "Implement me!"
  end
end

if $PROGRAM_NAME == __FILE__
  story_path = ARGV[0]
  unless story_path
    warn "Usage: #{$PROGRAM_NAME} STORY_FILE"
    exit 1
  end
  game = Game.new(story_path)
  game.play!
end
