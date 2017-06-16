require "sinatra"
require "octokit"
require "logger"
require "json"
require "faraday"
require "openssl"
require "base64"
require "sequel"

# Use one of the following depending on the platform that is sending
#   the webhook:
# https://api.travis-ci.org
# https://api.travis-ci.com
DEFAULT_API_HOST = "https://api.travis-ci.org"
API_HOST = ENV.fetch("API_HOST", DEFAULT_API_HOST)

post "/" do
  begin
    payload = params.fetch("payload")
    signature = request.env.fetch("HTTP_SIGNATURE")

    pkey = OpenSSL::PKey::RSA.new(public_key)

    unless pkey.verify(OpenSSL::Digest::SHA1.new, Base64.decode64(signature), payload)
      logger.info("verification failed")
      halt 400
    end

    logger.info("verification succeeded")
    payload = JSON.parse(payload)

    if auto_mergeable?(payload)
      pull_request_number = payload["pull_request_number"].to_i
      repo_name = payload.dig("repository", "name")
      repo_owner = payload.dig("repository", "owner_name")
      repo = "#{repo_owner}/#{repo_name}"

      pull_request = github_client.pull_request(repo, pull_request_number)
      branch_name = pull_request["head"]["ref"]

      github_client.merge_pull_request(repo, pull_request_number)
      logger.info("Merge branch: #{repo}:#{branch_name}")

      github_client.delete_branch(repo, branch_name)
      logger.info("Delete branch: #{repo}:#{branch_name}")

      logger.info("Auto merge completed!!")
    end

    status 200
  rescue => e
    logger.info "exception=#{e.class} message=\"#{e.message}\""
    logger.debug e.backtrace.join("\n")

    status 500
    "exception encountered while verifying signature"
  end
end

def public_key
  conn = Faraday.new(url: API_HOST) do |faraday|
    faraday.adapter Faraday.default_adapter
  end
  response = conn.get "/config"
  JSON.parse(response.body).dig("config", "notifications", "webhook", "public_key") or raise "Not found publickey"
end

def github_client
  @client ||= Octokit::Client.new(access_token: ENV.fetch("GITHUB_AUTH_TOKEN"))
end

def auto_mergeable?(payload)
  return false if payload["type"] != "pull_request"
  return false if payload["result_message"] != "Passed"
  return false if payload["author_name"] != ENV.fetch("BOT_NAME")
  return false if payload.dig("repository", "name") != ENV.fetch("REPOSITORY_NAME")
  return false if payload.dig("repository", "owner_name") != ENV.fetch("REPOSITORY_OWNER")
  return false if db[:pull_request_history].where(sha: payload["head_commit"]).empty?

  true
end

def db
  @db ||= Sequel.connect(ENV.fetch("DATABASE_URL"))
end
