require "csv"
require "ruboty/handlers/feedback/github-env"
require "ruboty/actions/github"

module Ruboty
  module Handlers
    module Feedback
      class Github < Base
        include Ruboty::Handlers::Feedback::GithubEnv

        on(%r{(?<url>https://github\.com/.+?/.+?/pull/\d+)},
           name: :pull_request,
           description: "Register feedback to the project on GitHub.com")

        on(%r{(?<url>https://github.com/.+?/.+?/issues/\d+)},
           name: :issue,
           description: "Register feedback to the project on GitHub.com")

        def pull_request(message)
          build_action(message).call
        rescue => ex
          message.reply("#{ex.class}: #{ex.message}")
          puts "#{ex.class}: #{ex.message}"
          puts ex.backtrace
        end

        def issue(message)
          build_action(message).call
        rescue => ex
          message.reply("#{ex.class}: #{ex.message}")
          puts "#{ex.class}: #{ex.message}"
          puts ex.backtrace
        end

        private

        def build_action(message)
          Ruboty::Actions::Github.new(message,
                                      access_token,
                                      statistics_repository,
                                      statistics_directory)
        end
      end
    end
  end
end
