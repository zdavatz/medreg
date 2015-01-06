#!/usr/bin/env ruby
# encoding: utf-8
require 'fileutils'

module Medreg
  DebugImport         ||= defined?(Minitest) ? true : false
  ARCHIVE_PATH = File.expand_path(File.join(Dir.pwd, 'data'))
  LOG_PATH     = File.expand_path(File.join(Dir.pwd, 'log'))
  Mechanize_Log = File.join(LOG_PATH, File.basename(__FILE__).sub('.rb', '.log'))
  FileUtils.mkdir_p(LOG_PATH)
  FileUtils.mkdir_p(ARCHIVE_PATH)
  FileUtils.mkdir_p(File.dirname(Mechanize_Log))
  ID = File.basename($0, '.rb')

  def Medreg.log(msg)
    $stdout.puts    "#{Time.now}:  #{ID} #{msg}" # unless defined?(Minitest)
    $stdout.flush
    @@logfile ||= File.open(File.join(LOG_PATH, "#{ID}.log"), 'a+')
    @@logfile.puts "#{Time.now}: #{msg}"
  end

  def Medreg.run(only_run=false)
    Medreg.log("Starting with only_run #{only_run}")
    import_company = (not only_run or only_run.match(/compan/i))
    import_person  = (not only_run or only_run.match(/person/i))
    if import_company
      importer = Medreg::CompanyImporter.new
      importer.update
    end
    if import_person
      importer = Medreg::PersonImporter.new
      importer.update
    end
    Medreg.log("Finished.")
  end
end

require 'medreg/company_importer'
require 'medreg/person_importer'
