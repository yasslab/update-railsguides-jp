require 'octokit'

head_branch_name = ARGV.first
base_branch_name = ENV["BASE_BRANCH_NAME"]

owner = ENV["REPOSITORY_OWNER"]
repo = ENV["REPOSITORY_NAME"]

exit(1) if head_branch_name.nil?

client = Octokit::Client.new(access_token: ENV["GITHUB_AUTH_TOKEN"])
client.create_pull_request("#{owner}/#{repo}", base_branch_name, head_branch_name, head_branch_name)
