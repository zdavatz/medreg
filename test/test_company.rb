#!/usr/bin/env ruby
# encoding: utf-8
# TestCompanyPlugin -- oddb.org -- 11.05.2012 -- yasaka@ywesee.com
# TestCompanyPlugin -- oddb.org -- 23.03.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('..', File.dirname(__FILE__))
$: << File.expand_path("../../src", File.dirname(__FILE__))

gem 'minitest'
require 'minitest/autorun'
require 'flexmock'
require 'medreg/company_importer'
require 'tempfile'

module Medreg
class TestCompanyPlugin <Minitest::Test
  include FlexMock::TestCase
  Test_Companies_XLSX = File.expand_path(File.join(__FILE__, '../data/companies_20141014.xlsx'))
  def rm_log_files
    FileUtils.rm_f(Dir.glob("#{Medreg::LOG_PATH}/*"), :verbose => true)
  end
  def setup
    rm_log_files
    $stderr.puts "Test_Companies_XLSX #{Test_Companies_XLSX}"
  end

  def test_update_7601002026444
    @plugin = Medreg::CompanyImporter.new([7601001396371])
    flexmock(@plugin, :get_latest_file => Test_Companies_XLSX)
    flexmock(@plugin, :get_company_data => {})
    flexmock(@plugin, :puts => nil)
    startTime = Time.now
    csv_file = Medreg::Companies_YAML
    FileUtils.rm_f(csv_file) if File.exists?(csv_file)
    created, updated, deleted, skipped = @plugin.update
    diffTime = (Time.now - startTime).to_i
    # $stdout.puts "result: created #{created} deleted #{deleted} skipped #{skipped} in #{diffTime} seconds"
    assert_equal(1, created)
    assert_equal(0, updated)
    assert_equal(0, deleted)
    assert_equal(0, skipped)
    assert_equal(1, Medreg::CompanyImporter.all_companies.size)
    assert(File.exists?(csv_file), "file #{csv_file} must be created")
    linden = Medreg::CompanyImporter.all_companies[7601001396371]
    addresses = linden[:addresses]
    assert_equal(1, addresses.size)
    first_address = addresses.first
    assert_equal(Medreg::Address2, first_address.class)
    assert_equal([], first_address.fon)
    assert_equal('5102 Rupperswil', first_address.location)
    assert_equal('öffentliche Apotheke', linden[:ba_type])
    assert_equal('5102', first_address.plz)
    assert_equal('Rupperswil', first_address.city)
    assert_equal('4', first_address.number)
    assert_equal('Mitteldorf', first_address.street)
    assert_equal([], first_address.additional_lines)
    assert_equal('AB Lindenapotheke AG', first_address.name)
    inhalt = IO.read(csv_file)
    assert(inhalt.index('6011 Verzeichnis a/b/c BetmVV-EDI') > 0, 'must find btm')
#	7601001396371	AB Lindenapotheke AG		Mitteldorf	4	5102	Rupperswil	Aargau	Schweiz	öffentliche Apotheke	6011 Verzeichnis a/b/c BetmVV-EDI
  end
  def test_update_all
    @plugin = Medreg::CompanyImporter.new()
    flexmock(@plugin, :get_latest_file => Test_Companies_XLSX)
    flexmock(@plugin, :get_company_data => {})
    flexmock(@plugin, :puts => nil)
    startTime = Time.now
    csv_file = Medreg::Companies_YAML
    FileUtils.rm_f(csv_file) if File.exists?(csv_file)
    created, updated, deleted, skipped = @plugin.update
    diffTime = (Time.now - startTime).to_i
    # $stdout.puts "result: created #{created} deleted #{deleted} skipped #{skipped} in #{diffTime} seconds"
    assert_equal(3, created)
    assert_equal(0, updated)
    assert_equal(0, deleted)
    assert_equal(1, skipped)
    assert(File.exists?(csv_file), "file #{csv_file} must be created")
  end

  def test_get_latest_file
    current  = File.expand_path(File.join(__FILE__, "../../../data/xls/companies_#{Time.now.strftime('%Y.%m.%d')}.xlsx"))
    FileUtils.rm_f(current) if File.exists?(current)
    @plugin = Medreg::CompanyImporter.new()
    res = @plugin.get_latest_file
    assert(res.match(Time.now.strftime('%Y.%m.%d')), "filename must match latest not #{res}")
    assert(File.size(Test_Companies_XLSX) <File.size(res))
  end
end
end