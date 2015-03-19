#!/usr/bin/env ruby

require "optparse"
require "platform-api"

heroku_api_token = ENV["HEROKU_PLATFORM_API_TOKEN"] || raise("No Heroku API key env variable set")

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{ARGV[0]} [options]"
  opts.on("-a", "--app NAME", 'Your heroku app name') { |v| options[:app] = v }
  opts.on("-p", "--process WEB_OR_WORKER", 'web or worker') { |v| options[:process] = v }
  opts.on("-q", "--quantity NUM_DYNOS", 'Number of dynos you want to scale to') { |v| options[:quantity] = v }
  opts.on("-s", "--size DYNO_SIZE", '1X, 2X or PX') { |v| options[:size] = v}
  opts.on("-c", "--concurrency WEB_CONCURRENCY", 'Default is based on dyno size') { |v| options[:web_concurrency] = v}
end.parse!

raise OptionParser::MissingArgument, "--app" if options[:app].nil?
raise OptionParser::MissingArgument, "--process" if options[:process].nil?
raise OptionParser::MissingArgument, "--quantity" if options[:quantity].nil?

heroku = PlatformAPI.connect_oauth(heroku_api_token)

#heroku = Heroku::API.new(api_key: heroku_api_key)

default_config = {
  'PX' => {
    'WEB_CONCURRENCY' => '15',
  },
  '2X' => {
    'WEB_CONCURRENCY' => '4',
    'RUBY_GC_HEAP_GROWTH_MAX_SLOTS' => '400000'
  },
  '1X' => {
    'WEB_CONCURRENCY' => '2',
  },
}

updates = {
  "process" => options[:process],
  "quantity" => options[:quantity]
}

config_updates = {}

if options[:size]
  options[:size].upcase!
  updates["size"] = options[:size]
  if default_config[options[:size]]['RUBY_GC_HEAP_GROWTH_MAX_SLOTS']
    config_updates['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] = default_config[options[:size]]['RUBY_GC_HEAP_GROWTH_MAX_SLOTS']
  else
    config_updates['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] = nil
  end
  if !options[:web_concurrency]
    config_updates['WEB_CONCURRENCY'] = default_config[options[:size]]['WEB_CONCURRENCY']
  end
end

config_updates['WEB_CONCURRENCY'] = options[:web_concurrency] if options[:web_concurrency]

heroku.config_var.update(options[:app], config_updates) if config_updates.size > 0

heroku.formation.batch_update(options[:app], {"updates" => [updates]})
