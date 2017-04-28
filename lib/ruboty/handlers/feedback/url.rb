require "octokit"
require "ruboty/handlers/github-env"

module Ruboty
  module Handlers
    module Feedback
      class URL < Ruboty::Handlers::Base
        include Ruboty::Handlers::GithubEnv

        on(%r!(?<type>report|patch|help) +(?<upstream>\S+?) +(?<url>#{URI.regexp})!,
           name: :register,
           description: "Register URL as a feedback")

        def register(message)
          github_user = user_for(message.from)
          type = message[:type]
          upstream = message[:upstream]
          url = message[:url]
          date = Date.today
          line = "#{date.iso8601},#{github_user},#{upstream},#{type},#{url}\n"
          update_feedback(date, line)
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

        def update_feedback(date, line)
          path = File.join(statistics_directory, "#{date.strftime('%Y-%m')}.csv")
          begin
            response = client.contents(statistics_repository, path: path)
            sha = response.sha
            content = Base64.decode64(response.content)
            if content.lines.include?(line)
              raise "Duplicated entry #{line}"
            end
            client.update_contents(statistics_repository,
                                   path,
                                   "Add feedback!!",
                                   sha,
                                   content + line)
          rescue Octokit::NotFound
            client.create_content(statistics_repository,
                                  path,
                                  "Add feedback!!",
                                  line)
          end
        end
      end
    end
  end
end
