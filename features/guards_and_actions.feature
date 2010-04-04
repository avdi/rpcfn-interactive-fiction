Feature: Guards and actions
  In order to kill even more time
  As an interactive fiction player
  I want to be presented with simple puzzles

  Background:
    When I start a new game with the file "petite_cave.if"

  Scenario: Try to enter locked grate
    Given I am at the grate
     When I enter "enter"
     Then I should see "You can't go through a locked steel grate!"

  Scenario: Try to unlock grate in wrong room
    Given I am in the building
     When I enter "unlock grate"
     Then I should see "There is no grate here"

  Scenario: Try to unlock grate without key
    Given I am at the grate
     When I enter "drop keys"
      And I enter "unlock grate"
     Then I should see "You have no keys!"

  Scenario: Unlock grate
    Given I am at the grate
     When I enter "unlock grate"
     Then I should see "The grate is now unlocked"
     When I enter "enter"
     Then I should see:
     """
     You are in a small chamber beneath a 3x3 steel grate to the surface.
     A low crawl over cobbles leads inward to the west.
     """
     When I enter "exit"
     Then I should be outside grate
     
