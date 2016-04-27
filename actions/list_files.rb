#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, details:false, json:true}
OptionParser.new do |opt|
   opt.banner = <<BAN
Lists all registered files from the results of a dataset or a project.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt.separator ""
   opt.on("-P", "--project PATH",
      "(Mandatory) Path to the project to read."){ |v| o[:project]=v }
   opt.on("-D", "--dataset STRING",
      "ID of the dataset to read. If not set, project-wide results are shown."
      ){ |v| o[:dataset]=v.miga_name }
   opt.on("-i", "--info",
      "If set, it prints additional details for each file."
      ){ |v| o[:details]=v }
   opt.on("--[no-]json",
      "If set to no, excludes json files containing results metadata."
      ){ |v| o[:json]=v }
   opt.on("-v", "--verbose",
      "Print additional information to STDERR."){ o[:q]=false }
   opt.on("-d", "--debug INT", "Print debugging information to STDERR.") do |v|
      v.to_i>1 ? MiGA::MiGA.DEBUG_TRACE_ON : MiGA::MiGA.DEBUG_ON
   end
   opt.on("-h", "--help", "Display this screen.") do
      puts opt
      exit
   end
   opt.separator ""
end.parse!


### MAIN
raise "-P is mandatory." if o[:project].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

if o[:dataset].nil?
   results = p.results
else
   $stderr.puts "Loading dataset." unless o[:q]
   ds = p.dataset(o[:dataset])
   raise "Impossible to load dataset: #{o[:dataset]}" if ds.nil?
   results = ds.results
end

$stderr.puts "Listing files." unless o[:q]
results.each do |result|
   puts "#{ "#{result.path}\t\t" if o[:details] }#{result.path}" if o[:json]
   result.each_file do |k,f|
      puts "#{ "#{result.path}\t#{k}\t" if o[:details] }#{result.dir}/#{f}"
   end
end

$stderr.puts "Done." unless o[:q]
