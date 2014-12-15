#!/usr/bin/env ruby

require "bundler"
require "optparse"

Bundler.require(:default)

heroku_api_key = ENV["HEROKU_API_KEY"] || raise("No Heroku API key env variable set")

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{ARGV[0]} [options]"
  opts.on("-a", "--app NAME", 'Your heroku app name') { |v| options[:app] = v }
  opts.on("-t", "--type DYNO_TYPE", 'web or worker') { |v| options[:dyno_type] = v }
  opts.on("-d", "--dynos NUM_DYNOS", 'Number of dynos you want to scale to') { |v| options[:count] = v }
  opts.on("-s", "--size DYNO_SIZE", '1X, 2X or PX') { |v| options[:dyno_size] = v}
  opts.on("-c", "--concurrency WEB_CONCURRENCY", 'Default is based on dyno size') { |v| options[:web_concurrency] = v}
end.parse!

raise OptionParser::MissingArgument, "--app" if options[:app].nil?
raise OptionParser::MissingArgument, "--type" if options[:dyno_type].nil?
raise OptionParser::MissingArgument, "--dynos" if options[:count].nil?

heroku = Heroku::API.new(api_key: heroku_api_key)

default_config = {
  'PX' => {
    'RUBY_GC_MALLOC_LIMIT' => '90000000',
    'WEB_CONCURRENCY' => '15',
  },
  '2X' => {
    'WEB_CONCURRENCY' => '6',
  },
  '1X' => {
    'WEB_CONCURRENCY' => '2',
  },
}

new_config = {}

if options[:dyno_size]
  heroku.put_formation(options[:app], options[:dyno_type] => options[:dyno_size])

  if options[:dyno_size] == 'PX'
    new_config['RUBY_GC_MALLOC_LIMIT'] = default_config['PX']['RUBY_GC_MALLOC_LIMIT']
  else
    heroku.delete_config_var(options[:app], 'RUBY_GC_MALLOC_LIMIT')
  end

  if !options[:web_concurrency]
    new_config['WEB_CONCURRENCY'] = default_config[options[:dyno_size]]['WEB_CONCURRENCY']
  end
end

if options[:web_concurrency]
  new_config['WEB_CONCURRENCY'] = options[:web_concurrency]
end

if new_config.size > 0
  heroku.put_config_vars(options[:app], new_config)
end

heroku.post_ps_scale(options[:app], options[:dyno_type], options[:count])
