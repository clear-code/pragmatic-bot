require "csv"

module Ruboty
  module Handlers
    module Contribution
      class Github < Base
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

        private

        def access_token
          ENV["GITHUB_ACCESS_TOKEN"]
        end
      end

      class Statistics < Base
        env :GITHUB_ACCESS_TOKEN, "GitHub.com access token"
        env :GITHUB_STATISTICS_REPOSITORY, "Statistics repository name on GitHub.com"
        env :GITHUB_STATISTICS_DIRECTORY, "Statistics under this directory"

        on(/\bstats\z/, name: :stats, description: "Statistics for all users")
        on(/\bstats (?<user>\w+)\z/, name: :stats_by_user, description: "Statistics for user")
        on(/\bstats (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})/,
           name: :stats_by_range,
           description: "Statistics for range. ex: 2017-04-01:2017-04-30")
        on(/\branking\z/, name: :ranking, description: "Ranking for all data")
        on(/\branking (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})/,
           name: :ranking_by_range,
           description: "Ranking by range")

        def stats(message)
          message.reply("stats: #{content.lines.size}")
        end

        def stats_by_user(message)
          lines = CSV.parse(content).select do |row|
            row[1] == message[:user]
          end
          message.reply("stats user: #{message[:user]} #{lines.size}")
        end

        def stats_by_range(message)
          start, last = message[:range].split(":")
          start = Date.parse(start)
          last = Date.parse(last)
          lines = CSV.parse(content).select do |row|
            date = Date.parse(row[0])
            (start..last).include?(date)
          end
          message.reply("stats range: #{message[:range]} #{lines.size}")
        end

        def ranking(message)
          ranking = Hash.new {|h, k| h[k] = 0 }
          CSV.parse(content).each do |row|
            ranking[row[1]] += 1
          end
          list = format_ranking(ranking)
          message.reply("stats ranking:\n\n#{list}")
        end

        def ranking_by_range(message)
          start, last = message[:range].split(":").map do |date|
            Date.parse(date)
          end
          ranking = Hash.new {|h, k| h[k] = 0 }
          CSV.parse(content).each do |row|
            ranking[row[1]] += 1 if (start..last).include?(Date.parse(raw[0]))
          end
          list = format_ranking(ranking)
          message.reply("ranking #{message[:range]}\n\n#{list}")
        end

        private

        def content
          response = client.contents(statistics_repository, path: statistics_directory)
          csv_files = response.map(&:path).select do |path|
            File.extname(path) == ".csv"
          end
          csv_files.map do |csv_file|
            response = client.contents(statistics_repository, path: csv_file)
            Base64.decode64(response.content)
          end.join
        end

        def format_ranking(ranking)
          ranking.to_a.sort_by {|_, n| -n }.map {|u, n| "#{u}:#{n}" }.join("\n")
        end

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
