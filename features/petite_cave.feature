Feature: Lead the user on an epic adventure
  In order to kill some time while waiting for a build to finish
  As a geek
  I want to play an interactive fiction game

  Background:
    When I start a new game with the file "petite_cave.if"

  Scenario: Starting a game
    Then I should see:
    """
    You are standing at the end of a road before a small brick building.
    Around you is a forest.  A small stream flows out of the building and
    down a gully.
    """

  Scenario: Moving around
    When I enter "west"
    Then I should see:
    """
    You are inside a building, a well house for a large spring.
    """
    When I enter "east"
    Then I should see:
    """
    You're at end of road again.
    """
  
