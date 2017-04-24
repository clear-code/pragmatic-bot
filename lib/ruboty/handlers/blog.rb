require "ruboty/handlers/feedback/github-env"
require "octokit"

module Ruboty
  module Handlers
    class Blog < Ruboty::Handlers::Base
      include Ruboty::Handlers::Feedback::GithubEnv

      on(%r!(?<url>https?://www\.clear-code\.com/blog/(?<date>.*)\.html)!,
         name: :register,
         description: "Register blog post.")

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
    end
  end
end
