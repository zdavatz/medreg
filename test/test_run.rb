#!/usr/bin/env ruby
# TestArray -- odba -- 30.01.2007 -- hwyss@ywesee.com

$: << File.dirname(__FILE__)
$: << File.expand_path('../lib', File.dirname(__FILE__))

require 'minitest/autorun'
require 'flexmock'
require 'medreg/medreg'

module ODBA
  class TestArray < Minitest::Test
    include FlexMock::TestCase
    def setup
    end
    def test_company_importer
      # TODO: assert Medreg.run('company')
    end
    def test_person_importer
      # TODO: assert Medreg.run('person')
    end
  end
end
