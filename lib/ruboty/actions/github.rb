require "octokit"

module Ruboty
  module Actions
    class Github < Ruboty::Actions::Base
      class DuplicateError < StandardError
      end

      NAMESPACE = "feedback_github"

      attr_reader :access_token, :statistics_repository, :statistics_directory

      def initialize(message, access_token, statistics_repository, statistics_directory)
        super(message)
        @access_token = access_token
        @statistics_repository = statistics_repository
        @statistics_directory = statistics_directory
      end

      def call
        if %r{\Ahttps://github\.com/(?<repo>.+?/.+?)/(?<type>(?:issues|pull))/(?<number>\d+)\z} =~ message[:url]
          register(repo, type, number)
          message.reply("Registered: #{message[:url]}")
        else
          message.reply("Could not register: #{message[:url]}")
        end
      rescue Ruboty::Actions::Github::DuplicateError
        message.reply("Duplicate: #{message[:url]}")
      end

      private

      def client
        @client ||= Octokit::Client.new(access_token: access_token)
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
        line = [date, user, upstream, type, url].join(",") + "\n"
        date = Date.parse(date)
        path = File.join(statistics_directory, "#{date.strftime('%Y-%m')}.csv")
        begin
          response = client.contents(statistics_repository, path: path)
          sha = response.sha
          content = Base64.decode64(response.content)
          if content.lines.include?(line)
            raise Ruboty::Actions::Github::DuplicateError
          end
          new_content = (content.lines + [line]).sort.join
          client.update_contents(statistics_repository,
                                 path,
                                 "Add feedback!!",
                                 sha,
                                 new_content)
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
