require "ruboty/handlers/feedback/github-env"
require "octokit"

module Ruboty
  module Handlers
    class Blog < Ruboty::Handlers::Base
      include Ruboty::Handlers::Feedback::GithubEnv

      on(%r!(?<url>https?://www\.clear-code\.com/blog/(?<date>.*)\.html)!,
         name: :register,
         description: "Register blog post.")
      on(/\bblog\z/, name: :stats, description: "Blog statistics for all users")
      on(/\bblog (?<user>\w+)\z/, name: :stats_by_user, description: "Blog statistics for user")
      on(/\bblog (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})\z/,
         name: :stats_by_range,
         description: "Statistics for range. ex: 2017-04-01:2017-04-30")
      on(/\bblog[-_]ranking\z/, name: :ranking, description: "Blog ranking")
      on(/\bblog[-_]ranking (?<range>\d{4}-\d{2}-\d{2}\:\d{4}-\d{2}-\d{2})/,
         name: :ranking_by_range,
         description: "Ranking by range. ex: 2017-04-01:2017-04-30")

      def register(message)
        github_user = user_for(message.from)
        url = message[:url]
        date = Date.parse(message[:date])
        line = "#{date.iso8601},#{github_user},#{url}\n"
        update_blog(date, line)
        message.reply("Registered: #{url}")
      rescue => ex
        message.reply("#{ex.class}: #{ex.message}")
        puts "#{ex.class}: #{ex.message}"
        puts ex.backtrace
      end

      def stats(message)
        message.reply("blog: #{content.lines.size}")
      end

      def stats_by_user(message)
        lines = CSV.parse(content).select do |row|
          row[1] == message[:user]
        end
        message.reply("blog user: #{message[:user]} #{lines.size}")
      end

      def stats_by_range(message)
        start, last = message[:range].split(":")
        start = Date.parse(start)
        last = Date.parse(last)
        lines = CSV.parse(content).select do |row|
          date = Date.parse(row[0])
          (start..last).include?(date)
        end
        message.reply("blog range: #{message[:range]} #{lines.size}")
      end

      def ranking(message)
        ranking = Hash.new {|h, k| h[k] = 0 }
        CSV.parse(content).each do |row|
          ranking[row[1]] += 1
        end
        list = format_ranking(ranking)
        message.reply("blog ranking:\n\n#{list}")
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
        message.reply("blog ranking #{message[:range]}\n\n#{list}")
      end

      private

      def client
        @client ||= Octokit::Client.new(access_token: access_token)
      end

      def update_blog(date, line)
        path = File.join(blog_directory, "#{date.strftime('%Y-%m')}.csv")
        begin
          response = client.contents(statistics_repository, path: path)
          sha = response.sha
          content = Base64.decode64(response.content)
          if content.lines.include?(line)
            raise "Duplicated entry #{line}"
          end
          client.update_contents(statistics_repository,
                                 path,
                                 "Add blog entry!!",
                                 sha,
                                 content + line)
        rescue Octokit::NotFound
          client.create_content(statistics_repository,
                                path,
                                "Add blog entry!!",
                                line)
        end
      end

      def content
        response = client.contents(statistics_repository, path: blog_directory)
        csv_files = response.map(&:path).select do |path|
          File.extname(path) == ".csv"
        end
        csv_files.map do |csv_file|
          response = client.contents(statistics_repository, path: csv_file)
          Base64.decode64(response.content)
        end.join
      end
    end
  end
end
