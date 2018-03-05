require "csv"
require "octokit"
require "ruboty/handlers/github-env"
require "ruboty/actions/github-statistics"

module Ruboty
  module Handlers
    module Feedback
      class Statistics < Base
        include Ruboty::Handlers::GithubEnv

        on(/\bstats\z/, name: :stats, description: "Statistics for all users")
        on(/\bstats (?<user>\w+)\s*(?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})?\z/, name: :stats_by_user, description: "Statistics for user")
        on(/\bstats (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})/,
           name: :stats_by_range,
           description: "Statistics for range. ex: 2017-04-01:2017-04-30")
        on(/\branking\z/, name: :ranking, description: "Ranking for all data")
        on(/\branking (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})/,
           name: :ranking_by_range,
           description: "Ranking by range. ex: 2017-04-01:2017-04-30")
        on(/\breload_stats\z/, name: :reload_stats, description: "Reload statistics")

        def stats(message)
          action(message).stats
        end

        def stats_by_user(message)
          action(message).stats_by_user
        end

        def stats_by_range(message)
          action(message).stats_by_range
        end

        def ranking(message)
          action(message).ranking
        end

        def ranking_by_range(message)
          action(message).ranking_by_range
        end

        def reload_stats(message)
          action(message, force_reload: true).reload_stats
        end

        private

        def action(message, force_reload: false)
          Ruboty::Actions::GithubStatistics.new(
            message,
            access_token,
            statistics_repository,
            statistics_directory,
            "feedback",
            force_reload: force_reload
          )
        end
      end
    end
  end
end
