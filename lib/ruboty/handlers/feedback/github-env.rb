module Ruboty
  module Handlers
    module Contribution
      module GithubEnv
        def self.included(base)
          base.class_eval do
            env :GITHUB_ACCESS_TOKEN, "GitHub.com access token"
            env :GITHUB_STATISTICS_REPOSITORY, "Statistics repository name on GitHub.com"
            env :GITHUB_STATISTICS_DIRECTORY, "Statistics under this directory"
            env :GITHUB_STATISTICS_BLOG_DIRECTORY, "Blog statistics under this directory"
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
      end
    end
  end
end
