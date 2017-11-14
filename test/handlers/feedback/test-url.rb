require "helper"
require "ruboty/handlers/feedback/url"

class TestURL < Test::Unit::TestCase
  setup do
    @robot = Ruboty::Robot.new
  end

  test "help with founder" do
    original = {
      body: "@ruboty https://github.com/okkez/pragmatic-bot/pull/1 help okkez/pragmatic-bot bob",
      from: "alice",
      to: "#general"
    }
    mock(Ruboty::Actions::Github).new(anything, "dummy", "dummy", "dummy") do
      lambda { }
    end
    @robot.receive(original)
    assert(true)
  end
end
