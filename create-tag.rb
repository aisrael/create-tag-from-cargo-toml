#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'octokit'
require 'toml-rb'

def attempt_to_get_git_sha_from_git(client, github_repository, branch_for_tag)
  client.branch(github_repository, branch_for_tag).commit.sha
rescue Octokit::NotFound
  puts "::error::Branch #{branch_for_tag} not found! Exiting..."
  exit 1
end

puts "ARGV => #{ARGV.inspect}"

CARGO_TOML = begin
  first = ARGV.shift
  first && !first.empty? ? first : 'Cargo.toml'
end

puts "CARGO_TOML => #{CARGO_TOML.inspect}"

# Read config file
unless File.exist?(CARGO_TOML)
  puts "::error::File #{CARGO_TOML} not found! Exiting..."
  exit 1
end
begin
  manifest = TomlRB.load_file(CARGO_TOML)
rescue Parslet::ParseFailed
  puts "::error::Failed to parse #{CARGO_TOML}! Exiting..."
  exit 1
end

# Get version
version = manifest.dig('package', 'version')
unless version
  puts "::error::Version not found in #{CARGO_TOML}! Exiting..."
  exit 1
end

semver = version.split('.')
unless semver.length == 3
  puts %(::error::Version "#{version}" is not a valid semver! Exiting...)
  exit 1
end

# Get GitHub token
token = ENV.fetch('GITHUB_TOKEN', nil)
if !token || token.empty?
  puts '::error::$GITHUB_TOKEN not provided! Exiting...'
  exit 1
end

github_repository = ENV.fetch('GITHUB_REPOSITORY', nil)
if !github_repository || github_repository.empty?
  puts '::error::$GITHUB_REPOSITORY not provided! Exiting...'
  exit 1
end

new_tag_name = "v#{version}"

# Create Octokit client
client = Octokit::Client.new(access_token: token)
client.auto_paginate = true

begin
  repo = client.repo(github_repository)
rescue Octokit::NotFound
  puts "::error::Repository #{github_repository} not found! Exiting..."
  exit 1
end

tags = client.tags(github_repository)

tag_names = tags.map(&:name)
if tag_names.include?(new_tag_name)
  puts "::error::Tag #{new_tag_name} already exists! Aborting..."
  exit 1
end

branch_for_tag = ENV['BRANCH_FOR_TAG'] || repo.default_branch || (tags.empty? ? 'main' : tags.first['branch'])

git_sha_for_tag = ENV['GIT_SHA_FOR_TAG'] || ENV['GITHUB_SHA'] || attempt_to_get_git_sha_from_git(client, github_repository, branch_for_tag)
puts "git_sha_for_tag => #{git_sha_for_tag}"

user = client.user

# Create tag
tagger_date = DateTime.now.iso8601
created_tag = client.create_tag(github_repository, new_tag_name, new_tag_name, git_sha_for_tag, 'commit', user.name, user.email, tagger_date)
puts "::startgroup::Created tag #{new_tag_name} pointing to #{git_sha_for_tag} on #{branch_for_tag}"
puts JSON.pretty_generate(created_tag.to_h)
puts '::endgroup::'

# Create the Git ref
created_ref = client.create_ref(github_repository, "refs/tags/#{new_tag_name}", git_sha_for_tag)
puts "::startgroup::Created ref #{created_ref.ref} pointing to #{created_ref.object.sha}"
puts JSON.pretty_generate(created_ref.to_h)
puts '::endgroup::'
