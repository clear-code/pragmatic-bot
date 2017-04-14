module Ruboty
  module Handlers
    module Contribution
      module GithubEnv
        def access_token
          ENV["GITHUB_ACCESS_TOKEN"]
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
      end
    end
  end
end
