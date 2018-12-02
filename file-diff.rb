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

data = {}
[ :first_file , :second_file].each do |fn|
  tmp_file_name = fn.to_s.gsub("_"," ")
  tmp_file = $inputs[fn]
  tmp_lines = (File.open(tmp_file , "r").readlines.size) - 1
  $log.info("Loading #{tmp_file_name} to memory (Number of lines: #{tmp_lines})...")
  data[fn] = {}
  progressbar = ProgressBar.create(:title => "Loading #{tmp_file_name}...", :starting_at => 0, :total => tmp_lines , :format => PROG_FORMAT , :output => $stderr )
  CSV.foreach( tmp_file , :col_sep => tmp_del , :headers => true) do |row|
    # TODO: Check headers
    row = row.to_hash
    tmp_key_arr = []
    $inputs[:key_cols].each do |k|
      tmp_key_arr << row[k]
    end
    tmp_key = tmp_key_arr.join(KEY_DELIM)
    raise "Key #{tmp_key} is not unique in #{tmp_file_name}." if data[fn].has_key?(tmp_key)
    data[fn][tmp_key] = row
    progressbar.increment
  end
  $log.info("...#{tmp_file_name} loaded.")
end

########################################
## Open files
########################################

singletons ={}
[ :first_file , :second_file ].each do |file|
  singletons[file] = CSV.open(OUTPUT_DIR + "/" + file.to_s + "_only.txt",'w' ,
      :col_sep => tmp_del ,
      :write_headers => true,
      :headers => data[file].first[1].keys
      )
end

diffs = CSV.open(OUTPUT_DIR + "/" + "diffs.txt",'w' ,
  :col_sep => tmp_del ,
  :write_headers => true,
  :headers => $inputs[:key_cols].concat(["COLUMN","FIRST_FILE","SECOND_FILE"])
  )

########################################
## Find differances
########################################

[
  [:first_file , :second_file],
  [:second_file , :first_file]
].each do |file_combo|
  $log.info("Comparing #{file_combo[0]} to #{file_combo[1]}...")
  progressbar = ProgressBar.create(:title => "Comparing #{file_combo[0].to_s.gsub("_file","")} to #{file_combo[1].to_s.gsub("_file","")}...", :starting_at => 0, :total => data[file_combo[0]].size, :format => PROG_FORMAT, :output => $stderr )
  data[file_combo[0]].each do |k,d|
    # Singleton: check if key exists in other file
    if data[file_combo[1]].has_key?(k)
      # Only performing diffing logic on first pass
      if file_combo[0] == :first_file
        tmp_diffs = diff = HashDiff.diff(data[file_combo[0]][k], data[file_combo[1]][k])
        tmp_diffs.each do |d|
          tmp_ignore = false
          $inputs[:ignored_columns].each do |c|
              tmp_ignore = true if /#{c}/ =~ d[1]
          end
          if not tmp_ignore
            diffs << k.split(KEY_DELIM).concat([ d[1] , d[2] , d[3] ])
          end
        end
      end
    else
      singletons[file_combo[0]] << d.values
    end
    progressbar.increment
  end
  $log.info("...files compared.")
end

# Close the files
singletons.each{ |k,v| v.close }
diffs.close
