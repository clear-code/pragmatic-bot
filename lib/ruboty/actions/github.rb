require "octokit"
require "ruboty/handlers/github-env"

module Ruboty
  module Actions
    class Github < Ruboty::Actions::Base
      class DuplicateError < StandardError
      end

      include Ruboty::Handlers::GithubEnv

      NAMESPACE = "feedback_github"

      attr_reader :access_token, :statistics_repository, :statistics_directory

      def initialize(message, access_token, statistics_repository, statistics_directory)
        super(message)
        @access_token = access_token
        @statistics_repository = statistics_repository
        @statistics_directory = statistics_directory
      end

      def call
        begin
          message[:type]
          have_type = true
        rescue IndexError
          have_type = false
        end
        if %r{\Ahttps://github\.com/(?<repo>.+?/.+?)/(?<type>(?:issues|pull))/(?<number>\d+)\z} =~ message[:url] && !have_type
          register(type: type, repo: repo, number: number)
        else
          register(type: message[:type])
        end
        message.reply("Registered: #{message[:url]}")
      rescue Ruboty::Actions::Github::DuplicateError
        message.reply("Duplicate: #{message[:url]}")
      end

      private

      def client
        @client ||= Octokit::Client.new(access_token: access_token)
      end

      def register(type:, repo: nil, number: nil)
        case type
        when "pull"
          register_pull_request(repo, number)
        when "issues"
          register_issue(repo, number)
        else
          register_url
        end
        register_finder
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
        line = [
          date,
          pull.user.login,
          pull.base.repo.full_name,
          :patch,
          pull.html_url
        ].join(",") + "\n"
        update_statistics(pull.created_at.localtime, line)
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
        line = [
          date,
          issue.user.login,
          repo,
          :report,
          issue.html_url
        ].join(",") + "\n"
        update_statistics(issue.created_at.localtime, line)
      end

      def register_url
        github_user = user_for(message.from)
        type = message[:type]
        upstream = message[:upstream]
        url = message[:url]
        date = Date.today
        records[date] ||= []
        records[date] << {
          user: github_user,
          upstream: upstream,
          type: type,
          url: url
        }
        line = "#{date.iso8601},#{github_user},#{upstream},#{type},#{url}\n"
        update_statistics(date, line)
      end

      def register_finder
        begin
          github_user = message[:finder]
          return if github_user.nil? || github_user.empty?
          type = "find"
          upstream = message[:upstream]
          url = message[:url]
          date = Date.today
          records[date] ||= []
          records[date] << {
            user: github_user,
            upstream: upstream,
            type: type,
            url: url
          }
          line = "#{date.iso8601},#{github_user},#{upstream},#{type},#{url}\n"
          update_statistics(date, line)
        rescue IndexError
          # do nothing
        end
      end

      def robot
        message.robot
      end

      def records
        robot.brain.data[NAMESPACE] ||= {}
      end

      def update_statistics(date, line)
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
