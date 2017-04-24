require "csv"
require "octokit"

module Ruboty
  module Actions
    class GithubStatistics < Ruboty::Actions::Base

      attr_reader :access_token, :repository, :base_directory, :label

      def initialize(message, access_token, repository, base_directory, label)
        super(message)
        @access_token = access_token
        @repository = repository
        @base_directory = base_directory
        @label = label
      end

      def stats
        message.reply("#{label}: #{content.lines.size}")
      end

      def stats_by_user
        lines = CSV.parse(content).select do |row|
          row[1] == message[:user]
        end
        message.reply("#{label} user: #{message[:user]} #{lines.size}")
      end

      def stats_by_range
        start, last = message[:range].split(":")
        start = Date.parse(start)
        last = Date.parse(last)
        lines = CSV.parse(content).select do |row|
          date = Date.parse(row[0])
          (start..last).include?(date)
        end
        message.reply("#{label} range: #{message[:range]} #{lines.size}")
      end

      def ranking
        ranking = Hash.new {|h, k| h[k] = 0 }
        CSV.parse(content).each do |row|
          ranking[row[1]] += 1
        end
        list = format_ranking(ranking)
        message.reply("#{label} ranking:\n\n#{list}")
      end

      def ranking_by_range
        start, last = message[:range].split(":").map do |date|
          Date.parse(date)
        end
        ranking = Hash.new {|h, k| h[k] = 0 }
        CSV.parse(content).each do |row|
          ranking[row[1]] += 1 if (start..last).include?(Date.parse(row[0]))
        end
        list = format_ranking(ranking)
        message.reply("#{label} ranking #{message[:range]}\n\n#{list}")
      end

      private

      def client
        @client ||= Octokit::Client.new(access_token: access_token)
      end

      def content
        response = client.contents(repository, path: base_directory)
        csv_files = response.map(&:path).select do |path|
          File.extname(path) == ".csv"
        end
        csv_files.map do |csv_file|
          response = client.contents(repository, path: csv_file)
          Base64.decode64(response.content)
        end.join
      end

      def format_ranking(ranking)
        ranking.to_a.sort_by {|_, n| -n }.map {|u, n| "#{u}:#{n}" }.join("\n")
      end
    end
  end
end
