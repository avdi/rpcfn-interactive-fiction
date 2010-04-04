WHITESPACE = "\t\n "

Before do
  @in  = StringIO.new
  @out = StringIO.new
end

AfterStep do
  # @in.string  = ""
  # @out.string = ""
end

When /^I start a new game with the file "([^\"]*)"$/ do |filename|
  @in.string  = ""
  @out.string = ""
  full_path = File.expand_path("../../data/#{filename}", File.dirname(__FILE__))
  @game = Game.new(full_path, :input => @in, :output => @out)
  @game.start!
end

Then /^I should see:$/ do |text|
  @out.string.tr_s(WHITESPACE, " ").should include(text.tr_s(WHITESPACE, " "))
end

When /^I enter "([^\"]*)"$/ do |command|
  @in.string = command + "\n"
  @out.string = ""
  @game.execute_one_command!
end
