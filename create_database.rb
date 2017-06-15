require 'sequel'

DB = Sequel.connect(ENV['DATABASE_URL'])

unless DB.table_exists?(:pull_request_history)
  DB.create_table(:pull_request_history) do
    primary_key :id
    String :sha
  end
end
