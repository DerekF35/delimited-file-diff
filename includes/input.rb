INPUT_CONFIG = {
  :project => {
    :short => "p",
    :full => "project",
    :description => "(REQUIRED) Path to project.  Will be created if doesn't exist.",
    :default => nil
  },
  :first_file => {
    :short => "1",
    :full => "first-file",
    :description => "Filename of first file, relative to the project directory.",
    :default => nil
  },
  :second_file => {
    :short => "2",
    :full => "second-file",
    :description => "Filename of second file, relative to the project directory.",
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
    :default => ["ID"]
  },
  :ignored_columns => {
    :short => "i",
    :full => "ignored-cols",
    :description => "Ignored columns. Provide comma seperated regexes or strings. Case sensitive.",
    :default => []
  },
}
SAVED_CONFIG_FILENAME="project-setup.yml"

$inputs = {}
INPUT_CONFIG.each{ |k, v| $inputs[k] = v[:default] }

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

$inputs[:project] = "./#{$inputs[:project]}"

# Check if project exists, create if not
unless File.directory?( $inputs[:project] )
  $log.info("Project directory does not exist.  I will create...")
  FileUtils.mkdir_p( $inputs[:project] )
  $log.info("...project directory created.")
end

# Check for config
##################

SAVED_CONFIG_FILE = "#{$inputs[:project]}/#{SAVED_CONFIG_FILENAME}"
if File.exists?( SAVED_CONFIG_FILE )
  #TODO: Ask if you want to load
  $log.info("Config file exists.  I will load...")
  tmp_setup = YAML.load_file(SAVED_CONFIG_FILE)
  $log.info("...configuration loaded: #{tmp_setup}")
  $log.info("Merging saved configuration...")
  tmp_setup = tmp_setup.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  $inputs.merge!(tmp_setup)
  $log.info("...configuration merged: #{$inputs}")
end

$inputs.each do |k,v|
  $log.info("Parameter #{k}: #{v}")
end

$inputs.each do |k,v|
  if v.nil?
    $log.fatal("No input value found for --#{k}")
    raise OptionParser::MissingArgument
  end
end
