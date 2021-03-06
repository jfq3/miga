# @package MiGA
# @license Artistic-2.0

##
# Metadata associated to objects like MiGA::Project, MiGA::Dataset, and
# MiGA::Result.
class MiGA::Metadata < MiGA::MiGA
  # Class-level

  ##
  # Does the metadata described in +path+ already exist?
  def self.exist?(path) File.exist? path end

  ##
  # Load the metadata described in +path+ and return MiGA::Metadata if it
  # exists, or nil otherwise.
  def self.load(path)
    return nil unless Metadata.exist? path
    MiGA::Metadata.new(path)
  end

  # Instance-level

  ##
  # Path to the JSON file describing the metadata.
  attr_reader :path

  ##
  # Initiate a MiGA::Metadata object with description in +path+. It will create
  # it if it doesn't exist.
  def initialize(path, defaults={})
    @data = nil
    @path = File.absolute_path(path)
    unless File.exist? path
      @data = {}
      defaults.each_pair{ |k,v| self[k]=v }
      create
    end
  end
  
  ##
  # Parsed data as a Hash.
  def data
    self.load if @data.nil?
    @data
  end

  ##
  # Reset :created field and save the current data.
  def create
    self[:created] = Time.now.to_s
    save
  end

  ##
  # Save the metadata into #path.
  def save
    MiGA.DEBUG "Metadata.save #{path}"
    self[:updated] = Time.now.to_s
    json = JSON.pretty_generate(data)
    sleeper = 0.0
    while File.exist?(lock_file)
      sleeper += 0.1 if sleeper <= 10.0
      sleep(sleeper.to_i)
    end
    FileUtils.touch lock_file
    ofh = File.open("#{path}.tmp", "w")
    ofh.puts json
    ofh.close
    raise "Lock-racing detected for #{path}." unless
      File.exist?("#{path}.tmp") and File.exist?(lock_file)
    File.rename("#{path}.tmp", path)
    File.unlink(lock_file)
  end

  ##
  # (Re-)load metadata stored in #path.
  def load
    sleeper = 0.0
    while File.exist? lock_file
      sleeper += 0.1 if sleeper <= 10.0
      sleep(sleeper.to_i)
    end
    # :symbolize_names does not play nicely with :create_additions
    tmp = JSON.parse(File.read(path),
      {:symbolize_names=>false, :create_additions=>true})
    @data = {}
    tmp.each_pair{ |k,v| self[k] = v }
  end

  ##
  # Delete file at #path.
  def remove!
    MiGA.DEBUG "Metadata.remove! #{path}"
    File.unlink(path)
    nil
  end

  ##
  # Lock file for the metadata.
  def lock_file ; "#{path}.lock" ; end

  ##
  # Return the value of +k+ in #data.
  def [](k) data[k.to_sym] end

  ##
  # Set the value of +k+ to +v+.
  def []=(k,v)
    self.load if @data.nil?
    k = k.to_sym
    # Protect the special field :name
    v=v.miga_name if k==:name
    # Symbolize the special field :type
    v=v.to_sym if k==:type
    # Delete if nil, register, and return
    v.nil? ? @data.delete(k) : (@data[k]=v)
  end

  ##
  # Iterate +blk+ for each data with 2 arguments key and value.
  def each(&blk) data.each{ |k,v| blk.call(k,v) } ; end

end
