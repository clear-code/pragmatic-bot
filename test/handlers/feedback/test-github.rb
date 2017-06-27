require "helper"
require "ruboty/handlers/feedback/github"

class TestGitHub < Test::Unit::TestCase
  setup do
    @robot = Ruboty::Robot.new
  end

  data(issues: "https://github.com/okkez/pragmatic-bot/issues/1",
       pull: "https://github.com/okkez/pragmatic-bot/pull/1",)
  test "issues or pull" do |url|
    original = {
      body: "@ruboty #{url}",
      from: "alice",
      to: "#general"
    }
    mock(Ruboty::Actions::Github).new(anything, "dummy", "dummy", "dummy") do
      lambda { }
    end
    @robot.receive(original)
    assert(true)
  end

  data(issues: "https://github.com/okkez/pragmatic-bot/issues/1 find okkez/pragmatic-bot",
       pull: "https://github.com/okkez/pragmatic-bot/pull/1 find okkez/pragmatic-bot",)
  test "issues or pull w/ garbage" do |url|
    original = {
      body: "@ruboty #{url}",
      from: "alice",
      to: "#general"
    }
    mock(Ruboty::Actions::Github).new(anything, "dummy", "dummy", "dummy").times(0)
    @robot.receive(original)
    assert(true)
  end
end
