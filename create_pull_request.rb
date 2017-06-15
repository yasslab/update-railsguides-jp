require "erb"
require "octokit"
require "sequel"

head_branch_name = ARGV.first
base_branch_name = ENV["BASE_BRANCH_NAME"]

hook_url = ENV["IDOBATA_HOOK_URL"]
owner_name = ENV["REPOSITORY_OWNER"]
repo_name = ENV["REPOSITORY_NAME"]
repo = "#{owner_name}/#{repo_name}"

exit(1) if head_branch_name.nil?

client = Octokit::Client.new(access_token: ENV["GITHUB_AUTH_TOKEN"])

pr = client.create_pull_request(repo, base_branch_name, head_branch_name, head_branch_name)
pr_id = pr["number"].to_i
pr_files = client.pull_request_files(repo, pr_id)

db = Sequel.connect(ENV["DATABASE_URL"])

table = db[:pull_request_history]
table.insert(sha: pr["head"]["sha"])

# 変更を監視するファイルパスのリスト
WATCH_LIST = [
  /^guides/,
  /Gemfile|Gemfile.lock/
]

files = pr_files.map do |f|
  if Regexp.union(WATCH_LIST).match?(f["filename"])
    f["filename"]
  end
end.compact

# 監視しているファイルに変更があった場合は通知する
if files.any?
  message = ERB.new(File.read("notify_message.html.erb"), nil, "-").result
  `curl -d format=html --data-urlencode "source=#{message}" #{hook_url}`
end
