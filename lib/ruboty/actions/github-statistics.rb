require "benchmark"
require "csv"
require "octokit"

module Ruboty
  module Actions
    class GithubStatistics < Ruboty::Actions::Base

      NAMESPACE = "feedback-github-statistics"

      attr_reader :access_token, :repository, :base_directory, :label

      def initialize(message, access_token, repository, base_directory, label)
        super(message)
        @access_token = access_token
        @repository = repository
        @base_directory = base_directory
        @label = label
      end

      def stats
        data = nil
        lines = nil
        elapsed_content = measure do
          data = content
        end
        elapsed_format = measure do
          lines = format_stats(CSV.parse(data))
        end
        message.reply("#{lines.join("\n")}\ntotal: #{data.lines.size}\nelapsed: #{elapsed_content} + #{elapsed_format}")
      end

      def stats_by_user
        begin
          start, last = message[:range].split(":").map {|d| Date.parse(d) }
        rescue IndexError
          # No range
          start, last = nil
        end

        rows = nil
        lines = nil
        _content = nil
        elapsed_content = measure do
          _content = content
        end
        elapsed_format = measure do
          rows = CSV.parse(_content).select do |row|
            if start && last
              row[1] == message[:user] && (start..last).include?(Date.parse(row[0]))
            else
              row[1] == message[:user]
            end
          end
          lines = format_stats(rows)
        end
        if start && last
          message.reply("#{label} user: #{message[:user]}\nrange: #{message[:range]}\n#{lines.join("\n")}\ntotal: #{rows.size}\nelapsed: #{elapsed_content} + #{elapsed_format}")
        else
          message.reply("#{label} user: #{message[:user]}\n#{lines.join("\n")}\ntotal: #{rows.size}\nelapsed: #{elapsed_content} + #{elapsed_format}")
        end
      end

      def stats_by_range
        start, last = message[:range].split(":")
        start = Date.parse(start)
        last = Date.parse(last)
        _content = nil
        elapsed_content = measure do
          _content = content
        end
        rows = nil
        lines = nil
        elapsed_format = measure do
          rows = CSV.parse(_content).select do |row|
            date = Date.parse(row[0])
            (start..last).include?(date)
          end
          lines = format_stats(rows)
        end
        message.reply("#{label} range: #{message[:range]}\n#{lines.join("\n")}\ntotal: #{rows.size}\nelapsed: #{elapsed_content} + #{elapsed_format}")
      end

      def ranking
        ranking = Hash.new {|h, k| h[k] = 0 }
        _content = nil
        elapsed_content = measure do
          _content = content
        end
        list = nil
        elapsed_format = measure do
          CSV.parse(_content).each do |row|
            ranking[row[1]] += 1
          end
          list = format_ranking(ranking)
        end
        message.reply("#{label} ranking:\n\n#{list}\nelapsed: #{elapsed_content} + #{elapsed_format}")
      end

      def ranking_by_range
        start, last = message[:range].split(":").map do |date|
          Date.parse(date)
        end
        ranking = Hash.new {|h, k| h[k] = 0 }
        _content = nil
        elapsed_content = measure do
          _content = content
        end
        list = nil
        elapsed_format = measure do
          CSV.parse(_content).each do |row|
            ranking[row[1]] += 1 if (start..last).include?(Date.parse(row[0]))
          end
          list = format_ranking(ranking)
        end
        message.reply("#{label} ranking #{message[:range]}\n\n#{list}\nelapsed: #{elapsed_content} + #{elapsed_format}")
      end

      private

      def client
        @client ||= Octokit::Client.new(access_token: access_token)
      end

      def content
        response = client.contents(repository, path: base_directory)
        csv_files = response.map(&:path).select do |path|
          File.extname(path) == ".csv"
        end.sort
        reset_content_cache_if_needed
        if content_cache.nil? || content_cache.empty?
          content_cache = csv_files[0..-2].map do |csv_file|
            response = client.contents(repository, path: csv_file)
            Base64.decode64(response.content)
          end.join
        end
        response = client.contents(repository, path: csv_files.last)
        content_cache + Base64.decode64(response.content)
      end

      def robot
        message.robot
      end

      def namespace
        "#{NAMESPACE}.#{@label}"
      end

      def content_cache
        robot.brain.data[namespace]
      end

      def content_cache=(text)
        robot.brain.data[namespace] = text
      end

      def reset_content_cache_if_needed
        return unless content_cache
        return if content_cache.empty?
        begin
          last_date = content_cache.lines.last.split(",", 2).first
          last_date = Date.parse(last_date)
          if last_date.month < Date.today.month
            content_cache = nil
          end
        rescue
          content_cache = nil
        end
      end

      def format_stats(rows)
        groups = rows.group_by do |row|
          row[3]
        end
        lines = groups.map do |type, _rows|
          "#{type}: #{_rows.size}"
        end
        lines.sort
      end

      def format_ranking(ranking)
        ranking.to_a.sort_by {|_, n| -n }.map {|u, n| "#{u}:#{n}" }.join("\n")
      end

      def measure
        elapsed = Benchmark.realtime do
          yield
        end
        "%.4f" % [elapsed]
      end
    end
  end
end
