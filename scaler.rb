#!/usr/bin/env ruby

require "bundler"
require "optparse"

Bundler.require(:default)

heroku_api_key = ENV["HEROKU_API_KEY"] || raise("No Heroku API key env variable set")

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{ARGV[0]} [options]"
  opts.on("-a", "--app NAME") { |v| options[:app] = v }
  opts.on("-t", "--type DYNO_TYPE") { |v| options[:type] = v }
  opts.on("-d", "--dynos NO_DYNOS") { |v| options[:count] = v }
end.parse!

raise OptionParser::MissingArgument, "--app" if options[:app].nil?
raise OptionParser::MissingArgument, "--type" if options[:type].nil?
raise OptionParser::MissingArgument, "--dynos" if options[:count].nil?

heroku = Heroku::API.new(api_key: heroku_api_key)
heroku.post_ps_scale options[:app], options[:type], options[:count]
