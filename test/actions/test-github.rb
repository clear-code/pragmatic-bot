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

  test "register help url w/ finder" do
    message = {
      url: "https://github.com/fluent/fluentd/pull/1603",
      type: "help",
      upstream: "fluent/fluentd",
      finder: "bob"
    }
    today = Date.today
    message.default_proc = ->(h, k) { raise IndexError }
    stub(message).reply(anything)
    stub(message).from { "alice" }
    action = create_action(message)
    stub(action).user_for("alice") { "alice" }
    stub(action).records.times(4) { { today => [] } }
    line1 = "#{today.iso8601},alice,fluent/fluentd,help,https://github.com/fluent/fluentd/pull/1603\n"
    line2 = "#{today.iso8601},bob,fluent/fluentd,find,https://github.com/fluent/fluentd/pull/1603\n"
    mock(action).update_statistics(today, line1)
    mock(action).update_statistics(today, line2)
    action.call
  end

  private

  def create_action(message)
    ::Ruboty::Actions::Github.new(message, "dummy", "dummy", "dummy")
  end
end
