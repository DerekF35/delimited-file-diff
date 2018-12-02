#!/usr/bin/env ruby

##################
## INCLUDES
##################

INCLUDES_DIR="./includes/"

require 'optparse'
require 'logger'
require 'fileutils'
require 'yaml'
require 'csv'
require 'hashdiff'
require 'ruby-progressbar'
require_relative INCLUDES_DIR + "Hash.rb"

##################
## SETUP
##################

$log = Logger.new(STDOUT)
$log.level = Logger::INFO
$log.level = Logger::DEBUG
KEY_DELIM="~"
PROG_FORMAT="%t |%B| %p%% %e"
DELMS = { "TAB" => "\t" , "COMMA" => "," , "PIPE" => "|" }

##################
## INPUT
##################

require_relative INCLUDES_DIR + "input.rb"

##################
## Methods
##################

def buildKey( data , keys , blank_value = "<BLANK_FIELD>" )
  tmp = []
  keys.each{ |k| tmp << ( data[k] || "<BLANK_FIELD>" ) }
  return tmp.join(KEY_DELIM)
end

#################
## Setup output
#################

OUTPUT_DIR=$inputs[:output]

#################
## Load files
#################

if DELMS.has_key?($inputs[:delimiter].upcase)
  tmp_del = DELMS[$inputs[:delimiter].upcase]
else
  tmp_del = $inputs[:delimiter]
end

first_file_keys = {}
second_file_data = {}
first_file_size = (File.open($inputs[:first_file] , "r").readlines.size) - 1
second_file_size = (File.open($inputs[:second_file] , "r").readlines.size) - 1

$log.info("Loading second file to memory (Number of lines: #{second_file_size})...")
progressbar = ProgressBar.create(:title => "Loading second file...", :starting_at => 0, :total => second_file_size , :format => PROG_FORMAT , :output => $stderr )
CSV.foreach( $inputs[:second_file] , :col_sep => tmp_del , :headers => true) do |row|
  # TODO: Check headers
  row = row.to_hash
  tmp_key = buildKey( row , $inputs[:key_cols] )
  raise "Key #{tmp_key} is not unique in second file." if second_file_data.has_key?(tmp_key)
  second_file_data[tmp_key] = row
  progressbar.increment
end
$log.info("...second file loaded.")

########################################
## Open files
########################################

singletons ={}
[ :first_file , :second_file ].each do |file|
  singletons[file] = CSV.open(OUTPUT_DIR + "/" + file.to_s + "_only.txt",'w' ,
      :col_sep => tmp_del ,
      :write_headers => true,
      :headers => second_file_data.first[1].keys
      )
end

diffs = CSV.open(OUTPUT_DIR + "/" + "diffs.txt",'w' ,
  :col_sep => tmp_del ,
  :write_headers => true,
  :headers => $inputs[:key_cols].clone.concat(["COLUMN","FIRST_FILE","SECOND_FILE"])
  )

########################################
## Find differances
########################################

$log.info("Comparing first file to second file...")
progressbar = ProgressBar.create(:title => "Comparing first to second...", :starting_at => 0, :total => first_file_size, :format => PROG_FORMAT, :output => $stderr )
CSV.foreach( $inputs[:first_file] , :col_sep => tmp_del , :headers => true) do |first_file_row|
  # TODO: Check headers
  first_file_row = first_file_row.to_hash
  k = buildKey( first_file_row , $inputs[:key_cols] )
  # Singleton: check if key exists in other file
  if first_file_keys.has_key?(k)
    raise "Key #{k} is not unique in second file."
  else
    first_file_keys[k] = true
  end

  if second_file_data.has_key?(k)
    tmp_diffs = diff = HashDiff.diff( first_file_row , second_file_data[k])
    tmp_diffs.each do |d|
      tmp_ignore = false
      $inputs[:ignored_columns].each do |c|
          tmp_ignore = true if /#{c}/ =~ d[1]
      end
      if not tmp_ignore
        diffs << k.split(KEY_DELIM).concat([ d[1] , d[2] , d[3] ])
      end
    end
  else
    singletons[:first_file] << first_file_row.values
  end
  progressbar.increment
end
$log.info("...files compared.")


$log.info("Comparing second file to first file...")
progressbar = ProgressBar.create(:title => "Comparing second to first...", :starting_at => 0, :total => second_file_size, :format => PROG_FORMAT, :output => $stderr )
second_file_data.each do |k,d|
  if !first_file_keys.has_key?(k)
    singletons[:second_file] << d.values
    progressbar.increment
  end
end
$log.info("...files compared.")

# Close the files
singletons.each{ |k,v| v.close }
diffs.close
