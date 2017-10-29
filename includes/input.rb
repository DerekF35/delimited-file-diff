INPUT_CONFIG = {
  :output => {
    :short => "o",
    :full => "output",
    :description => "(REQUIRED) Path to output directory.  Will be created if doesn't exist.",
    :default => nil
  },
  :first_file => {
    :short => "1",
    :full => "first-file",
    :description => "First file to compare.",
    :default => nil
  },
  :second_file => {
    :short => "2",
    :full => "second-file",
    :description => "Second file to compare.",
    :default => nil
  },
  :delimiter => {
    :short => "d",
    :full => "delimiter",
    :description => "Delimited for input files. (Options: tab, comma)  Default: tab",
    :default => "tab",
  },
  :key_cols => {
    :short => "k",
    :full => "key-cols",
    :description => "Key columns, comma seperated & case sensitive.",
    :default => nil
  },
  :ignored_columns => {
    :short => "i",
    :full => "ignored-cols",
    :description => "Ignored columns. Provide comma seperated regexes or strings. Case sensitive.",
    :default => []
  },
}
SAVED_CONFIG_FILENAME="run-setup.yml"

$inputs = {}
defaults = {}
INPUT_CONFIG.each{ |k, v| defaults[k] = v[:default] }

parser = OptionParser.new do|opts|
  opts.banner = "Usage: file-diff.rb [options]"

  INPUT_CONFIG.each do |k,x|
    opts.on( "-#{x[:short]}", "--#{x[:full]} input"  , x[:description] ) do | input |
         $inputs[k] = input
    end
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end

end

parser.parse!

# Process project
#################

# Check if project exists, create if not
unless File.directory?( $inputs[:output] )
  $log.info("Project directory does not exist.  I will create...")
  FileUtils.mkdir_p( $inputs[:output] )
  $log.info("...project directory created.")
end

# Process keys
#################

if $inputs.has_key?(:key_cols)
  $inputs[:key_cols] = $inputs[:key_cols].split(",")
end

# Check for config
##################

SAVED_CONFIG_FILE = "#{$inputs[:output]}/#{SAVED_CONFIG_FILENAME}"
if File.exists?( SAVED_CONFIG_FILE )
  #TODO: Ask if you want to load
  $log.info("Config file exists.  I will load...")
  tmp_setup = YAML.load_file(SAVED_CONFIG_FILE)
  $log.info("...configuration loaded: #{tmp_setup}")
  $log.info("Merging saved configuration...")
  tmp_setup = tmp_setup.collect{|k,v| [k.to_sym, v]}.to_h

  $inputs = defaults.merge(tmp_setup.merge($inputs))
  $log.info("...configuration merged: #{$inputs}")
end

$inputs.each do |k,v|
  $log.info("Parameter #{k}: #{v}")
end

$log.info("Saving configuration file to output location...")
File.open( SAVED_CONFIG_FILE , 'w') { |f| f.write $inputs.collect{|k,v| [k.to_s, v]}.to_h.to_yaml }
$log.info("... configuration file saved.")

$inputs.each do |k,v|
  if v.nil?
    $log.fatal("No input value found for --#{k}")
    raise OptionParser::MissingArgument
  end
end
