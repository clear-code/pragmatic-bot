require "csv"
require "ruboty/handlers/github-env"
require "ruboty/actions/github"

module Ruboty
  module Handlers
    module Feedback
      class Gitlab < Base
        include Ruboty::Handlers::GithubEnv

        on(%r{(?<url>https://gitlab\.com/.+?/.+?/merge_requests/\d+)\z},
           name: :pull_request,
           description: "Register feedback to the project on GitHub.com")

        on(%r{(?<url>https://gitlab\.com/.+?/.+?/issues/\d+)\z},
           name: :issue,
           description: "Register feedback to the project on GitLab.com")

        on(%r{(?<url>https://gitlab\.gnome\.org/.+?/.+?/merge_requests/\d+)\z},
           name: :pull_request,
           description: "Register feedback to the project on gitlab.gnome.org")

        on(%r{(?<url>https://gitlab\.gnome\.org/.+?/.+?/issues/\d+)\z},
           name: :issue,
           description: "Register feedback to the project on gitlab.gnome.org")

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
          Ruboty::Actions::Gitlab.new(message,
                                      statistics_repository,
                                      statistics_directory)
        end
      end
    end
  end
end
