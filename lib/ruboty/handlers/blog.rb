require "ruboty/handlers/github-env"
require "ruboty/actions/github-statistics"
require "octokit"

module Ruboty
  module Handlers
    class Blog < Ruboty::Handlers::Base
      include Ruboty::Handlers::GithubEnv

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
      on(/\breload_blog\z/, name: :reload_stats, description: "Reload blog statistics")

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

      def action(message, force_reload: false)
        Ruboty::Actions::GithubStatistics.new(
          message,
          access_token,
          statistics_repository,
          blog_directory,
          "blog",
          force_reload: force_reload
        )
      end
    end
  end
end
