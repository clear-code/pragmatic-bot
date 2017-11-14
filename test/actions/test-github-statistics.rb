require "helper"
require "ruboty/actions/github-statistics"

class TestGithubStatistics < Test::Unit::TestCase
  def test_stats
    message = {
      user: "okkez",
    }
    mock(message).reply(<<~MESSAGE.chomp)
      find: 2
      help: 1
      info: 4
      patch: 5
      report: 3
      total: 15
    MESSAGE
    action = create_action(message)
    mock(action).content { fixture_path("feedback.csv").read }
    action.stats
  end

  def test_stats_by_user
    message = /\A(?<user>\w+)\z/.match("kou")
    mock(message).reply(<<~MESSAGE.chomp)
      feedback user: kou
      find: 1
      help: 1
      patch: 1
      report: 1
      total: 4
    MESSAGE
    action = create_action(message)
    mock(action).content { fixture_path("feedback.csv").read }
    action.stats_by_user
  end

  def test_stats_by_user_with_range
    message = {
      user: "kou",
      range: "2017-06-01:2017-06-02"
    }
    mock(message).reply(<<~MESSAGE.chomp)
      feedback user: kou
      range: 2017-06-01:2017-06-02
      find: 1
      help: 1
      patch: 1
      report: 1
      total: 4
    MESSAGE
    action = create_action(message)
    mock(action).content { fixture_path("feedback.csv").read }
    action.stats_by_user
  end

  def test_stats_by_range
    message = {
      user: "okkez",
      range: "2017-06-01:2017-06-02"
    }
    mock(message).reply(<<~MESSAGE.chomp)
      feedback range: 2017-06-01:2017-06-02
      find: 2
      help: 1
      info: 4
      patch: 4
      report: 3
      total: 14
    MESSAGE
    action = create_action(message)
    mock(action).content { fixture_path("feedback.csv").read }
    action.stats_by_range
  end

  private

  def create_action(message)
    ::Ruboty::Actions::GithubStatistics.new(message, "dummy", "dummy", "dummy", "feedback")
  end
end
