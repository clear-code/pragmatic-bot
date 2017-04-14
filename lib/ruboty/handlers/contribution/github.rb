require "csv"
require "ruboty/handlers/contribution/github-env"

module Ruboty
  module Handlers
    module Contribution
      class Github < Base
        include Ruboty::Handlers::Contribution::GithubEnv

        env :GITHUB_ACCESS_TOKEN, "GitHub.com access token"
        env :GITHUB_STATISTICS_REPOSITORY, "Statistics repository name on GitHub.com"
        env :GITHUB_STATISTICS_DIRECTORY, "Statistics under this directory"

        on(%r{(?<url>https://github\.com/.+?/.+?/pull/\d+)},
           name: :pull_request,
           description: "Register contribution to the project on GitHub.com")

        on(%r{(?<url>https://github.com/.+?/.+?/issues/\d+)},
           name: :issue,
           description: "Register contribution to the project on GitHub.com")

        def pull_request(message)
          Ruboty::Actions::Contribution::Github.new(message).call
        end

        def issue(message)
          Ruboty::Actions::Contribution::Github.new(message).call
        end
      end
    end
  end
end

require "octokit"

module Ruboty
  module Actions
    module Contribution
      class DuplicateError < StandardError
      end
      class Github < Ruboty::Actions::Base

        NAMESPACE = "contribution_github"

        def call
          if %r{\Ahttps://github\.com/(?<repo>.+?/.+?)/(?<type>(?:issues|pull))/(?<number>\d+)\z} =~ message[:url]
            register(repo, type, number)
            message.reply("Registered: #{message[:url]}")
          else
            message.reply("Could not register: #{message[:url]}")
          end
        rescue Ruboty::Actions::Contribution::DuplicateError
          message.reply("Duplicate: #{message[:url]}")
        end

        private

        def client
          @client ||= Octokit::Client.new(access_token: access_token)
        end

        def access_token
          ENV["GITHUB_ACCESS_TOKEN"]
        end

        def statistics_repository
          ENV["GITHUB_STATISTICS_REPOSITORY"]
        end

        def statistics_directory
          ENV["GITHUB_STATISTICS_DIRECTORY"]
        end

        def register(repo, type, number)
          case type
          when "pull"
            register_pull_request(repo, number)
          when "issues"
            register_issue(repo, number)
          end
        end

        def register_pull_request(repo, number)
          pull = client.pull_request(repo, number)
          date = pull.created_at.localtime.strftime("%Y-%m-%d")
          records[date] ||= []
          records[date] << {
            user: pull.user.login,
            upstream: pull.base.repo.full_name,
            type: :patch,
            url: pull.html_url
          }
          update_statistics(date: date,
                            user: pull.user.login,
                            upstream: pull.base.repo.full_name,
                            type: :patch,
                            url: pull.html_url)
        end

        def register_issue(repo, number)
          issue = client.issue(repo, number)
          date = issue.created_at.localtime.strftime("%Y-%m-%d")
          records[date] ||= []
          records[date] << {
            user: issue.user.login,
            upstream: repo,
            type: :report,
            url: issue.html_url
          }
          update_statistics(date: date,
                            user: issue.user.login,
                            upstream: repo,
                            type: :report,
                            url: issue.html_url)
        end

        def robot
          message.robot
        end

        def records
          robot.brain.data[NAMESPACE] ||= {}
        end

        def update_statistics(date:, user:, upstream:, type:, url:)
          line = [date, user, upstream, type, url, "\n"].join(",")
          date = Date.parse(date)
          path = File.join(statistics_directory, "#{date.strftime('%Y-%m')}.csv")
          begin
            response = client.contents(statistics_repository, path: path)
            sha = response.sha
            content = Base64.decode64(response.content)
            if content.lines.include?(line)
              raise DuplicateError
            end
            client.update_contents(statistics_repository,
                                   path,
                                   "Add contribution!!",
                                   sha,
                                   content + line)
          rescue Octokit::NotFound
            client.create_content(statistics_repository,
                                  path,
                                  "Add contribution!!",
                                  line)
          end
        end
      end
    end
  end
end
