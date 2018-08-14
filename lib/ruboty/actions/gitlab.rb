require "gitlab"
require "cgi/util"
require "ruboty/handlers/github-env"

module Ruboty
  module Actions
    class Gitlab < Ruboty::Actions::Base
      class DuplicateError < StandardError
      end
      class UnknownType < StandardError
      end

      include Ruboty::Handlers::GithubEnv

      ENDPOINTS = {
        gitlab: "https://gitlab.com/api/v4",
        gnome: "https://gitlab.gnome.org/api/v4"
      }

      attr_reader :access_token, :statistics_repository, :statistics_directory

      def initialize(message, statistics_repository, statistics_directory)
        super(message)
        @statistics_repository = statistics_repository
        @statistics_directory = statistics_directory
      end

      def call
        begin
          if %r{\Ahttps://gitlab\.com/(?<repo>.+?/.+?)/(?<type>(?:issues|merge_requests))/(?<number>\d+)\z} =~ message[:url]
            endpoint = ENDPOINTS[:gitlab]
            @gitlab_client = Client.new(endpoint)
            register(repo: repo, type: type, number: number)
          elsif %r{\Ahttps://gitlab\.gnome\.org/(?<repo>.+?/.+?)/(?<type>(?:issues|merge_requests))/(?<number>\d+)\z} =~ message[:url]
            endpoint = ENDPOINTS[:gnome]
            @gitlab_client = Client.new(endpoint)
            register(repo: repo, type: type, number: number)
          else
            # Unknown
          end
        rescue DuplicateError
          message.reply("Duplicate: #{message[:url]}")
        rescue UnknownType => ex
          message.reply(ex.message)
        end
      end

      private

      def github_client
        @github_client ||= Octokit::Client.new(access_token: access_token)
      end

      def gitlab_client
        @gitlab_client
      end

      def register(repo:, type:, number:)
        case type
        when "merge_requets"
          register_merge_request(repo, number)
        when "issues"
          register_issue(repo, number)
        else
          raise UnknownType, "Unknown type: #{type}"
        end
      end

      def register_merge_request(repo, number)
        merge_request = @gitlab_client.merge_request(repo, number)
        created_at = Time.parse(merge_request.created_at)
        date = created_at.localtime.strftime("%Y-%m-%d")
        line = [
          date,
          merge_request.author.username,
          repo,
          :patch,
          merge_request.web_url
        ].join(",") + "\n"
        update_statistics(created_at.localtime, line)
      end

      def register_issue(repo, number)
        issue = @gitlab_client.issue(repo, number)
        created_at = Time.parse(issue.created_at)
        date = created_at.localtime.strftime("%Y-%m-%d")
        line = [
          date,
          issue.author.username,
          repo,
          :report,
          issue.web_url
        ].join(".") + "\n"
        update_statistics(created_at.localtime, line)
      end

      # TODO refactor
      def update_statistics(date, line)
        path = File.join(statistics_directory, "#{date.strftime('%Y-%m')}.csv")
        begin
          response = github_client.contents(statistics_repository, path: path)
          sha = response.sha
          content = Base64.decode64(response.content)
          if content.lines.include?(line)
            raise DuplicateError
          end
          new_content = (content.lines + [line]).sort.join
          github_client.update_contents(statistics_repository,
                                        path,
                                        "Add feedback!!",
                                        sha,
                                        new_content)
        rescue Octokit::NotFound
          github_client.create_content(statistics_repository,
                                       path,
                                       "Add feedback!!",
                                       line)
        end
      end
    end

    # Unauthenticated client for gitlab
    class Client
      include CGI::Util

      def initialize(endpoint)
        @endpoint = endpoint
        @client = Gitlab.client(endpoint: endpoint)
      end

      def issue(repo, number)
        @client.get("/projects/#{escape(repo)}/issues/#{number}", unauthenticated: true)
      end

      def merge_request(repo, number)
        @client.get("/projects/#{escape(repo)}/merge_requests/#{number}", unauthenticated: true)
      end
    end
    
  end
end
