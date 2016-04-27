#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, add:false, ref:false}
OptionParser.new do |opt|
  opt.banner = <<BAN
Finds unregistered datasets based on result files.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
  opt.separator ""
  opt.on("-P", "--project PATH",
    "(Mandatory) Path to the project to use."){ |v| o[:project]=v }
  opt.on("-a", "--add",
    "Register the datasets found. By default, only lists them (dry run)."
    ){ |v| o[:add]=v }
  opt.on("-t", "--type STRING",
    "Type of datasets. Recognized types include:",
    *MiGA::Dataset.KNOWN_TYPES.map{ |k,v| "~ #{k}: #{v[:description]}"}
    ){ |v| o[:type]=v.to_sym }
  opt.on("-r", "--ref",
    "If set, all datasets are registered as reference datasets."
    ){ |v| o[:ref]=v }
  opt.on("-u", "--user STRING", "Owner of the dataset."){ |v| o[:user]=v }
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

$stderr.puts "Finding datasets." unless o[:q]
ud = p.unregistered_datasets
ud.each do |dn|
  puts dn
  if o[:add]
    md = {}
    [:type, :user].each{ |k| md[k]=o[k] unless o[k].nil? }
    d = MiGA::Dataset.new(p, dn, o[:ref], md)
    p.add_dataset(dn)
    res = d.first_preprocessing
    puts "- #{res}" unless o[:q]
  end
end

$stderr.puts "Done." unless o[:q]