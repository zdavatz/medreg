#!/usr/bin/env ruby
# encoding: utf-8
require 'fileutils'
require 'medreg/company_importer'

module Medreg
  ARCHIVE_PATH = File.expand_path(File.join(File.dirname(__FILE__), '../../data'))
  LOG_PATH     = File.expand_path(File.join(File.dirname(__FILE__), '../../log'))
  Mechanize_Log         = File.join(LOG_PATH, File.basename(__FILE__).sub('.rb', '.log'))
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
    unless only_run
      importer = Medreg::CompanyImporter.new
      importer.update
    end
    Medreg.log("Finished.")
  end
end
