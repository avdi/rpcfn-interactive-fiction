Feature: Lead the user on an epic adventure
  In order to kill some time while waiting for a build to finish
  As an old-school geek
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
    When I enter "east"
    Then I should see:
    """
    You are inside a building, a well house for a large spring.
    """
    When I enter "west"
    Then I should see:
    """
    You're at end of road again.
    """
    When I enter "south"
    Then I should see:
    """
    You are in a valley in the forest beside a stream tumbling along a
    rocky bed.
    """
    When I enter "south"
    Then I should see:
    """
    At your feet all the water of the stream splashes into a 2-inch slit
    in the rock.  Downstream the streambed is bare rock.
    """
    When I enter "south"
    Then I should see:
    """
    You are in a 20-foot depression floored with bare dirt.  Set into the
    dirt is a strong steel grate mounted in concrete.  A dry streambed
    leads into the depression.
    """
  
  Scenario: Blocked movement
    When I enter "east"
     And I enter "east"
    Then I should see:
    """
    There is no way to go in that direction
    """
     And I should not see "inside building"

  Scenario: Looking around
    When I enter "east"
     And I enter "look"
    Then I should see:
    """
    You are inside a building, a well house for a large spring.
    """
    When I enter "west"
     And I enter "look"
    Then I should see:
    """
    You are standing at the end of a road before a small brick building.
    Around you is a forest.  A small stream flows out of the building and
    down a gully.
    """

  Scenario: Synonyms
    When I enter "e"
    Then I should be inside a building
    When I enter "w"
    Then I should be at end of road
    When I enter "l"
    Then I should see "You are standing at the end of a road"

  Scenario: Show objects
    When I enter "east"
    Then I should see "There are some keys on the ground here."
     And I should see "There is a shiny brass lamp nearby."
     And I should see "There is food here."
    When I enter "look"
    Then I should see "There are some keys on the ground here."
     And I should see "There is a shiny brass lamp nearby."
     And I should see "There is food here."

  Scenario: Starting inventory
    When I enter "inventory"
    Then I should see "You're not carrying anything"
     And I should not see "keys"

  Scenario: Pick up an object
    Given I am in the building
     When I enter "get keys"
     Then I should see "OK"
     When I enter "look"
     Then I should not see "keys"
     When I enter "inventory"
     Then I should see "Set of keys"

  Scenario: Drop an object
    When I enter "look"
    Then I should not see "keys"
    When I enter "east"
     And I enter "get keys"
     And I enter "west"
     And I enter "drop keys"
     And I enter "look"
    Then I should see "There are some keys on the ground here."
    When I enter "inventory"
    Then I should not see "keys"

  Scenario Outline:
    Given I am in the building
     When I pick up the <term>
     Then I should have the <object>

  Scenarios: object synonyms
    | object        | term          |
    | Brass lantern | lantern       |
    | Brass lantern | brass lantern |
    | Brass lantern | lamp          |
    | Brass lantern | brass lamp    |
    | Small bottle  | bottle        |
    | Small bottle  | water         |
    | Small bottle  | small bottle  |
    | Tasty food    | food          |

