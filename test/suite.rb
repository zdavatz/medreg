#!/usr/bin/env ruby
# encoding: utf-8

$: << File.expand_path(File.dirname(__FILE__))
# require 'minitest'
require 'simplecov'
SimpleCov.start

Dir.foreach(File.dirname(__FILE__)) { |file|
	require file if /^test_.*\.rb$/o.match(file)
}
