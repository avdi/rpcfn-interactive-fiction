#!/usr/bin/env ruby

class Game
  # TODO implement me!
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
