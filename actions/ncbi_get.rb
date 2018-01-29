#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require 'miga/remote_dataset'

o = {q:true, query:false, unlink:false,
      reference: false, ignore_plasmids: false,
      complete:false, chromosome:false,
      scaffold:false, contig:false,}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on("-T", "--taxon STRING",
        "(Mandatory unless --reference) Name of the taxon (e.g., a species binomial)."
        ){ |v| o[:taxon]=v }
  opt.on("--reference",
        "Download all reference genomes (ignores -T)."){ |v| o[:reference]=v }
  opt.on("--ref-no-plasmids",
        "If passed, ignores plasmids (only for --reference)."
        ){ |v| o[:ignore_plasmids]=v }
  opt.on("--complete", "Download complete genomes."){ |v| o[:complete]=v }
  opt.on("--chromosome", "Download complete chromosomes."){ |v| o[:chromosome]=v }
  opt.on("--scaffold", "Download genomes in scaffolds."){ |v| o[:scaffold]=v }
  opt.on("--contig", "Download genomes in contigs."){ |v| o[:contig]=v }
  opt.on("-q", "--query",
        "If set, the datasets are registered as queries, not reference datasets."
        ){ |v| o[:query]=v }
  opt.on("-u", "--unlink",
        "If set, unlinks all datasets in the project missing from the download list"
        ){ |v| o[:unlink]=v }
  opt_common(opt, o)
end.parse!

opt_require(o, project: "-P")
opt_require(o, taxon: "-T") unless o[:reference]
unless %w[reference complete chromosome scaffold contig].any?{ |i| o[i.to_sym] }
  raise "No action requested. Pick at least one type of genome"
end

##=> Main <=
$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?
d = []
ds = {}
downloaded = 0

def get_list(taxon, status)
  url_base = "https://www.ncbi.nlm.nih.gov/genomes/Genome2BE/genome2srv.cgi?"
  url_param = if status==:reference
    { action: "refgenomes", download: "on" }
  else
    { action: "download", report: "proks", group: "-- All Prokaryotes --",
          subgroup: "-- All Prokaryotes --", orgn: "#{taxon}[orgn]",
          status: status }
  end
  url = url_base + URI.encode_www_form(url_param)
  response = RestClient::Request.execute(method: :get, url:url, timeout:600)
  unless response.code == 200
    raise "Unable to reach NCBI, error code #{response.code}."
  end
  response.to_s
end

# Download IDs with reference status
if o[:reference]
  $stderr.puts "Downloading reference genomes" unless o[:q]
  lineno = 0
  get_list(nil, :reference).each_line do |ln|
    next if (lineno+=1)==1
    r = ln.chomp.split("\t")
    next if r[3].empty?
    ids = r[3].split(",")
    ids += r[5].split(",") unless o[:ignore_plasmids] or r[5].empty?
    n = r[2].miga_name
    ds[n] = {ids: ids, md: {type: :genome}, db: :nuccore, universe: :ncbi}
  end
end

# Download IDs with complete or chromosome status
if o[:complete] or o[:chromosome]
  status = (o[:complete] and o[:chromosome] ? "50|40" : o[:complete] ? "50" : "40")
  $stderr.puts "Downloading complete/chromosome genomes" unless o[:q]
  lineno = 0
  get_list(o[:taxon], status).each_line do |ln|
    next if (lineno+=1)==1
    r = ln.chomp.split("\t")
    ids = r[10].gsub(/[^:;]*:/,"").gsub(/\/[^\/;]*/,"").split(";")
    n = (r[0] + "_" + ids[0]).miga_name
    ds[n] = {ids: ids, md: {type: :genome}, db: :nuccore, universe: :ncbi}
  end
end

# Download IDs with scaffold or contig status
if o[:scaffold] or o[:contig]
  status = (o[:scaffold] and o[:contig] ? "30|20" : o[:scaffold] ? "30" : "20")
  $stderr.puts "Downloading scaffold/contig genomes" unless o[:q]
  lineno = 0
  get_list(o[:taxon], status).each_line do |ln|
    next if (lineno+=1)==1
    r = ln.chomp.split("\t")
    asm = r[7].gsub(/[^:;]*:/,"").gsub(/\/[^\/;]*/,"").gsub(/\s/,"")
    ids = r[19].gsub(/\s/, "").split(";").map{ |i| i + "/" + File.basename(i) + "_genomic.fna.gz" }
    n = (r[0] + "_" + asm).miga_name
    comm = "Assembly: #{asm}"
    ds[n] = {ids: ids, md: {type: :genome, comments: comm}, db: :assembly_gz, universe: :web}
  end
end

# Download entries
$stderr.puts "Downloading #{ds.size} #{ds.size>1 ? "entries" : "entry"}." unless o[:q]
ds.each do |name,body|
  d << name
  puts name
  next unless p.dataset(name).nil?
  $stderr.puts "  Locating remote dataset." unless o[:q]
  rd = MiGA::RemoteDataset.new(body[:ids], body[:db], body[:universe])
  $stderr.puts "  Creating dataset." unless o[:q]
  rd.save_to(p, name, !o[:query], body[:md])
  p.add_dataset(name)
  downloaded += 1
end

# Finalize
$stderr.puts "Datasets listed: #{d.size}" unless o[:q]
$stderr.puts "Datasets downloaded: #{downloaded}" unless o[:q]
if o[:unlink]
  unlink = p.dataset_names - d
  unlink.each { |i| p.unlink_dataset(i).remove! }
  $stderr.puts "Datasets unlinked: #{unlink.size}" unless o[:q]
end
