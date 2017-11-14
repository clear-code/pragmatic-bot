require "octokit"
require "ruboty/handlers/github-env"
require "ruboty/actions/github"

module Ruboty
  module Handlers
    module Feedback
      class URL < Ruboty::Handlers::Base
        include Ruboty::Handlers::GithubEnv

        on(%r!(?<url>#{URI.regexp}) +(?<type>report|patch|help|find|info) +(?<upstream>\S+)(?: +(?<finder>\w+))?!,
           name: :register,
           description: "Register URL as a feedback")

        def register(message)
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
