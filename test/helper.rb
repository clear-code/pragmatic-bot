ENV["RUBOTY_ENV"] = "test"

ENV["GITHUB_ACCESS_TOKEN"] = "dummy"
ENV["GITHUB_STATISTICS_REPOSITORY"] = "dummy"
ENV["GITHUB_STATISTICS_DIRECTORY"] = "dummy"
ENV["GITHUB_STATISTICS_BLOG_DIRECTORY"] = "dummy"
ENV["GITHUB_USERS_MAP_FILE"] = "dummy"

require "test-unit"
require "test-unit-notify"
require "test/unit/rr"
require "ruboty"
