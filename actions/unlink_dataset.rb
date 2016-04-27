#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, remove:false}
OptionParser.new do |opt|
   opt.banner = <<BAN
Removes a dataset from an MiGA project.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt.separator ""
   opt.on("-P", "--project PATH",
      "(Mandatory) Path to the project to use."){ |v| o[:project]=v }
   opt.on("-D", "--dataset PATH",
      "(Mandatory) ID of the dataset to create."){ |v| o[:dataset]=v }
   opt.on("-r", "--remove",
      "Also remove all associated files.",
      "By default, only unlinks from metadata."){ o[:remove]=true }
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
raise "-D is mandatory." if o[:dataset].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Unlinking dataset." unless o[:q]
raise "Dataset doesn't exist, aborting." unless
   MiGA::Dataset.exist?(p, o[:dataset])
d = p.unlink_dataset(o[:dataset])
d.remove! if o[:remove]

$stderr.puts "Done." unless o[:q]
