require "yaml"

module Ruboty
  module Handlers
    module GithubEnv
      def self.included(base)
        base.class_eval do
          break unless method_defined?(:env)
          env :GITHUB_ACCESS_TOKEN, "GitHub.com access token"
          env :GITHUB_STATISTICS_REPOSITORY, "Statistics repository name on GitHub.com"
          env :GITHUB_STATISTICS_DIRECTORY, "Statistics under this directory"
          env :GITHUB_STATISTICS_BLOG_DIRECTORY, "Blog statistics under this directory"
          env :GITHUB_USERS_MAP_FILE, "Path to GitHub users and emails map in YAML format"
        end
      end

      def access_token
        ENV["GITHUB_ACCESS_TOKEN"]
      end

      def statistics_repository
        ENV["GITHUB_STATISTICS_REPOSITORY"]
      end

      def statistics_directory
        ENV["GITHUB_STATISTICS_DIRECTORY"]
      end

      def blog_directory
        ENV["GITHUB_STATISTICS_BLOG_DIRECTORY"]
      end

      def users_map_file
        ENV["GITHUB_USERS_MAP_FILE"]
      end

      def user_for(email)
        @users ||= YAML.load_file(users_map_file)
        @users[email]
      end
    end
  end
end
