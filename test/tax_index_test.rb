require "test_helper"
require "miga/tax_index"

class TaxIndexTest < Test::Unit::TestCase
  
  def test_initialization
    ti = MiGA::TaxIndex.new
    assert_equal(:root, ti.root.rank)
  end

  def test_dataset
    $tmp = Dir.mktmpdir
    ENV["MIGA_HOME"] = $tmp
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_rc")
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_daemon.json")
    p = MiGA::Project.new(File.expand_path("project1", $tmp))
    d = p.add_dataset("dataset1")
    
    ti = MiGA::TaxIndex.new
    assert(ti.datasets.empty?)
    ti << d
    assert(ti.datasets.empty?, "Index should ignore datasets without tax.")
    d.metadata[:tax] = MiGA::Taxonomy.new("k:Fantasia g:Unicornia")
    ti << d
    assert_equal(1, ti.datasets.size, "Index should have one dataset.")
    assert_equal(1, ti.root.datasets_count)
  ensure
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
  end

  def test_to_json
    js = JSON.parse(MiGA::TaxIndex.new.to_json)
    assert(js.keys.include? "datasets")
    assert_equal(2, js.keys.size)
    assert(js["datasets"].empty?)
  end

  def test_to_tab
    ti = MiGA::TaxIndex.new
    assert_equal("root:biota: 0\n", ti.to_tab)
  end

end
