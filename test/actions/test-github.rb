require "helper"
require "ruboty/actions/github"

class TestGithub < Test::Unit::TestCase

  test "register github pull request" do
    message = {
      url: "https://github.com/fluent/fluentd/pull/1603"
    }
    stub(message).[](:type).once { raise IndexError }
    stub(message).[](:url) { "https://github.com/fluent/fluentd/pull/1603" }
    stub(message).reply(anything)
    action = create_action(message)
    mock(action).register(type: "pull", repo: "fluent/fluentd", number: "1603")
    action.call
  end

  test "register github pull request w/ type" do
    message = {
      url: "https://github.com/fluent/fluentd/pull/1603",
      type: "help",
      upstream: "fluent/fluentd"
    }
    stub(message).reply(anything)
    action = create_action(message)
    mock(action).register(type: "help")
    action.call
  end

  private

  def create_action(message)
    ::Ruboty::Actions::Github.new(message, "dummy", "dummy", "dummy")
  end
end
