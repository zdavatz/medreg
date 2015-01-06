#!/usr/bin/env ruby
# encoding: utf-8

$: << File.expand_path('..', File.dirname(__FILE__))
$: << File.expand_path("../lib", File.dirname(__FILE__))
puts File.expand_path("../lib", File.dirname(__FILE__))
gem 'minitest'
require 'minitest/autorun'
require 'flexmock'
require 'medreg/person_importer'
require 'tempfile'
require 'ostruct'

Minitest::Test.i_suck_and_my_tests_are_order_dependent!()

class TestPerson <Minitest::Test
  include FlexMock::TestCase
  RunTestTakingLong = false
  Test_Personen_XLSX = File.expand_path(File.join(__FILE__, '../data/Personen_20141014.xlsx'))
  def rm_log_files
    FileUtils.rm_f(Dir.glob("#{Medreg::LOG_PATH}/*"), :verbose => true)
  end

  def setup
    rm_log_files
  end

  SomeTestCases = {
    7601000010735 => OpenStruct.new(:family_name => 'Cevey',        :first_name => 'Philippe Marc', :authority  => 'Waadt'),
    7601000813282 => OpenStruct.new(:family_name => 'ABANTO PAYER', :first_name => 'Dora Carmela',  :authority  => 'Waadt'),
  }
  # Anita Hensel 7601000972620
  def test_aaa_zuest # name starts with aaa we want this test to be run as first
    {  7601000254207 => OpenStruct.new(:family_name => 'Züst', :first_name => 'Peter', :authority  => 'Glarus')}.each do
      |gln, info|
       rm_log_files
      @plugin = Medreg::PersonImporter.new([gln])
      flexmock(@plugin, :get_latest_file => Test_Personen_XLSX )
      flexmock(@plugin, :get_doctor_data => {})
      assert(File.exists?(Test_Personen_XLSX) , "File #{Test_Personen_XLSX} must exist")
      startTime = Time.now
      csv_file = Medreg::Personen_YAML
      FileUtils.rm_f(csv_file) if File.exists?(csv_file)
      created, updated, deleted, skipped = @plugin.update
      diffTime = (Time.now - startTime).to_i
      assert_equal(0, deleted)
      assert_equal(0, skipped)
      assert_equal(1, created)
      assert_equal(0, updated)
      assert_equal(1, Medreg::Person.all_doctors.size)
      zuest = Medreg::Person.all_doctors.first[1] # a hash
      assert_equal(true, zuest[:may_dispense_narcotics])
      assert_equal(true, zuest[:may_sell_drugs])
      assert_equal(nil, zuest[:remark_sell_drugs])
      assert_equal(nil, zuest[:exam])
      assert_equal('Züst', zuest[:name])
      assert_equal('Peter', zuest[:firstname])
      assert_equal(["Allgemeine Innere Medizin, 2003, Schweiz"], zuest[:specialities])
      assert_equal(3, zuest[:capabilities].size)
      [ "Sportmedizin, 2004, Schweiz",
        "Praxislabor, 2002, Schweiz",
        "Sachkunde für dosisintensives Röntgen, 2004, Schweiz",
      ].each {
        |cap|
          assert(zuest[:capabilities].index(cap), "Muss Erfahrung #{cap} fuer Züst finden")
      }
      addresses = zuest[:addresses]
      assert_equal(1, addresses.size)
      first_address = addresses.first
       assert_equal(Medreg::Address2, first_address.class)
      assert_equal(1, first_address.fon.size)
      assert_equal(['Bahnhofstr. 3'], first_address.additional_lines)
      assert_equal('8753 Mollis', first_address.location)
      assert_equal('at_praxis', first_address.type)
      assert_equal('055 6122353', first_address.fon.first)
      assert_equal('Praxis Dr. med. Peter Züst', first_address.name)
      assert_equal('8753', first_address.plz)
      assert_equal('Mollis', first_address.city)
      assert_equal('Bahnhofstr.', first_address.street)
      assert_equal('3', first_address.number)
    end
  end
  def test_update_with_error
    gln = 9999
    info = OpenStruct.new(:family_name => 'NoName', :first_name => 'NoFirstName', :authority  => 'NoSuchCanton')
    @plugin = Medreg::PersonImporter.new([gln])
    flexmock(@plugin, :get_latest_file => Test_Personen_XLSX )
    flexmock(@plugin, :get_doctor_data => {})
    assert(File.exists?(Test_Personen_XLSX))
    startTime = Time.now
    yaml_file = Medreg::Personen_YAML
    csv_file = yaml_file.sub('.yaml', '.csv')
    FileUtils.rm_f(csv_file) if File.exists?(csv_file)
    FileUtils.rm_f(yaml_file) if File.exists?(yaml_file)
    created, updated, deleted, skipped = @plugin.update
    diffTime = (Time.now - startTime).to_i
    assert_equal(0, deleted)
    assert_equal(0, skipped)
    assert_equal(0, created)
    assert_equal(0, updated)
    assert(File.exists?(yaml_file), "file #{csv_file} must be created")
    assert(/ERROR: could not find info for GLN/.match(@plugin.report), 'Should find error')
    assert(/New doctors: 0/.match(@plugin.report), 'Should find 0 new doctor')
  end
  def test_update_single
    gln = 7601000254207
    info = OpenStruct.new(:family_name => 'Züst', :first_name => 'Peter',  :authority  => 'Glarus')
      rm_log_files
    @plugin = Medreg::PersonImporter.new([gln])
    flexmock(@plugin, :get_latest_file => Test_Personen_XLSX )
    flexmock(@plugin, :get_doctor_data => {})
    assert(File.exists?(Test_Personen_XLSX))
    startTime = Time.now
    yaml_file = Medreg::Personen_YAML
    csv_file = yaml_file.sub('.yaml', '.csv')
    FileUtils.rm_f(csv_file) if File.exists?(csv_file)
    FileUtils.rm_f(yaml_file) if File.exists?(yaml_file)
    created, updated, deleted, skipped = @plugin.update
    diffTime = (Time.now - startTime).to_i
    assert_equal(0, deleted)
    assert_equal(0, skipped)
    assert_equal(1, created)
    assert_equal(0, updated)
    assert(File.exists?(yaml_file), "file #{csv_file} must be created")
    assert_equal(nil, /ERROR: could not find info for GLN/.match(@plugin.report), 'Should not find an error')
    assert(/New doctors: 1/.match(@plugin.report), 'Should find 1 new doctor')
    yaml_inhalt = IO.read(yaml_file)
    assert(yaml_inhalt.size > 50, "yaml file #{yaml_file} should be bigger than 50 char, but is #{yaml_inhalt.size}")
    assert(File.exists?(csv_file), "file #{csv_file} must be created")
    csv = IO.readlines(csv_file)
    assert(csv.size > 1, "csv file #{csv_file} should have more than 1 line. Has  #{csv.size}")
    csv_inhalt = IO.read(csv_file)
    assert(csv_inhalt.size > 50, "csv file #{csv_file} should be bigger than 50 char, but is #{csv_inhalt.size}")
  end

  def test_update_some_glns
    glns_ids_to_search = [7601000078261, 7601000813282, 7601000254207, 7601000186874, 7601000201522, 7601000295958,
                          7601000010735, 7601000268969, 7601000019080, 7601000239730 ]
    @plugin = Medreg::PersonImporter.new(glns_ids_to_search)

    flexmock(@plugin, :get_latest_file => Test_Personen_XLSX )
    flexmock(@plugin, :get_doctor_data => {})
    assert(File.exists?(Test_Personen_XLSX))
    startTime = Time.now
    csv_file = Medreg::Personen_YAML
    FileUtils.rm_f(csv_file) if File.exists?(csv_file)
    created, updated, deleted, skipped = @plugin.update
    diffTime = (Time.now - startTime).to_i
    assert_equal(0, deleted)
    assert_equal(0, skipped)
    assert_equal(0, updated)
    assert_equal(glns_ids_to_search.size - 1 , created) # we have one gln_id mentioned twice
    assert(File.exists?(csv_file), "file #{csv_file} must be created")
  end if RunTestTakingLong

  def test_zzz_get_latest_file # name starts with zzz we want this test to be run as last one (takes longest)
    @plugin = Medreg::PersonImporter.new([7601000813282])
    needs_update, latest = @plugin.get_latest_file
  end if RunTestTakingLong

  def test_parse
    SomeTestCases.each{
      |gln, info|
      info.gln = gln
      root = File.expand_path(File.join(__FILE__, "../.."))
      @plugin = Medreg::PersonImporter.new([gln])
      html_file = File.expand_path(File.join(__FILE__, "../data/#{gln}.html"))
      assert(File.exist?(html_file), "File #{html_file} must exist")
      doc_hash = @plugin.parse_details(Nokogiri::HTML(File.read(html_file)),
                                      gln,
                                      info,
                                      )
      assert(doc_hash.is_a?(Hash), 'doc_hash must be a Hash')
      assert(doc_hash[:addresses], 'doc_hash must have addresses')
      assert(doc_hash[:addresses].size > 0, 'doc_hash must have at least one address')
    }
  end

end
