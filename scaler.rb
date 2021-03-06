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
  opts.on("-s", "--size DYNO_SIZE", '1X, 2X or PX') { |v| options[:size] = v.downcase }
  opts.on("-c", "--concurrency WEB_CONCURRENCY", 'Default is based on dyno size') { |v| options[:web_concurrency] = v}
end.parse!

raise OptionParser::MissingArgument, "--app" if options[:app].nil?
raise OptionParser::MissingArgument, "--process" if options[:process].nil?
raise OptionParser::MissingArgument, "--quantity" if options[:quantity].nil?

# Simple class to only add a config change if it's not already set
module Scaler
  class Config
    attr_accessor :updates
    def initialize(current)
      @current = current
      @updates = {}
    end

    def update(key, value)
      if @current[key] != value
        @updates[key] = value
      end
    end

    def update_all(values)
      values.each do |key, value|
        update(key, value)
      end
    end
  end
end

heroku = PlatformAPI.connect_oauth(heroku_api_token)

default_config = {
  'standard-1x' => {
    'WEB_CONCURRENCY' => '2',
  },
  'standard-2x' => {
    'WEB_CONCURRENCY'                    => '4',
    'RUBY_GC_HEAP_GROWTH_MAX_SLOTS'      => '400000',
    'RUBY_GC_HEAP_GROWTH_FACTOR'         => '1.1',
    'RUBY_GC_MALLOC_LIMIT'               => '16000000',
    'RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR' => '1.1',
    'RUBY_GC_MALLOC_LIMIT_MAX'           => '16000000',
    'RUBY_GC_OLDMALLOC_LIMIT'            => '16000000',
    'RUBY_GC_OLDMALLOC_LIMIT_MAX'        => '16000000',
  },
  'performance-l' => {
    'WEB_CONCURRENCY' => '15',
    'RUBY_GC_HEAP_GROWTH_MAX_SLOTS'      => nil,
    'RUBY_GC_HEAP_GROWTH_FACTOR'         => nil,
    'RUBY_GC_MALLOC_LIMIT'               => nil,
    'RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR' => nil,
    'RUBY_GC_MALLOC_LIMIT_MAX'           => nil,
    'RUBY_GC_OLDMALLOC_LIMIT'            => nil,
    'RUBY_GC_OLDMALLOC_LIMIT_MAX'        => nil,
  },
}

formation_updates = {
  "process"  => options[:process],
  "quantity" => options[:quantity]
}

app               = options[:app]
size              = options[:size]
preboot_enabled   = heroku.app_feature.info(app, 'preboot')["enabled"]
current_formation = heroku.formation.info(app, options[:process])
current_config    = heroku.config_var.info(app)
config            = Scaler::Config.new(current_config)
commands          = [:config, :formation]

# Are we changing dyno sizes?
if size && size != current_formation["size"]
  puts "Will change size from #{current_formation['size']} to #{size}."
  formation_updates["size"] = size

  # only set with default config if not passed as an option
  if options[:web_concurrency]
    default_config[size]['WEB_CONCURRENCY'] = options[:web_concurrency]
  end

  # setting values to nil will unset the config value
  if default_config[size].nil?
    puts "#{size} was not found in the default configuration settings. Please use one of: #{default_config.keys}."
    exit
  end

  config.update_all(default_config[size])

  # The direction determines the order of the commands
  # If we are scaling UP, update formation before updating config
  if size == 'performance-l' || (size == 'standard-2X' && current_formation['size'] == 'Standard-1X')
    puts "Switching command order to formation, then config}"
    commands = [:formation, :config]
  end
else
  puts "No change in dyno size necessary."
end

# if preboot is enabled and we're running more than one dyno,
# we have to sleep 3 minutes between commands, otherwise we get H99 errors
if preboot_enabled && (current_formation["quantity"].to_i != 1 && options[:quantity].to_i != 1)
  sleep_duration = 3 * 60
else
  sleep_duration = 0
end

previous_command_executed = false

puts "Commands in order are #{commands.inspect}"

commands.each_with_index do |command, index|
  # sleep before second command, only when necessary
  if index == 1 && previous_command_executed
    puts "Sleeping for #{sleep_duration} seconds between commands"
    sleep(sleep_duration)
  end

  case command
  when :config
    if config.updates.size > 0
      puts "Updating configuration: #{config.updates.inspect}"
      heroku.config_var.update(app, config.updates)
      previous_command_executed = true
    else
      puts "No config updates are necessary, skipping."
    end
  when :formation
    puts "Updating formation: #{formation_updates.inspect}"
    heroku.formation.batch_update(app, {"updates" => [formation_updates]})
    previous_command_executed = true
  else
    raise "Unknown command #{command}"
  end
end

puts "Done"
