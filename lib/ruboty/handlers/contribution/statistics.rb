require "csv"
require "octokit"
require "ruboty/handlers/contribution/github-env"

module Ruboty
  module Handlers
    module Contribution
      class Statistics < Base
        include Ruboty::Handlers::Contribution::GithubEnv

        on(/\bstats\z/, name: :stats, description: "Statistics for all users")
        on(/\bstats (?<user>\w+)\z/, name: :stats_by_user, description: "Statistics for user")
        on(/\bstats (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})/,
           name: :stats_by_range,
           description: "Statistics for range. ex: 2017-04-01:2017-04-30")
        on(/\branking\z/, name: :ranking, description: "Ranking for all data")
        on(/\branking (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})/,
           name: :ranking_by_range,
           description: "Ranking by range. ex: 2017-04-01:2017-04-30")

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
            ranking[row[1]] += 1 if (start..last).include?(Date.parse(row[0]))
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
      end
    end
  end
end
