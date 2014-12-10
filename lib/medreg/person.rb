#!/usr/bin/env ruby
# encoding: utf-8

$: << File.expand_path("../../src", File.dirname(__FILE__))

require 'medreg'
require 'medreg/address'
module Medreg
  class Person
    attr_accessor :capabilities, :title, :name, :firstname,
      :email, :exam, :language, :specialities,
      :praxis, :member, :salutation,
      :origin_db, :origin_id, :addresses, :ean13,
      :dummy_id,
      :experiences,
      :may_dispense_narcotics, :may_sell_drugs, :remark_sell_drugs
    alias :name_first :firstname
    alias :name_first= :firstname=
    alias :correspondence :language
    alias :correspondence= :language=

    def initialize
      @addresses = []
      @experiences = []
    end
    def fullname
      [@firstname, @name].join(' ')
    end
    def praxis_address
      @addresses.find { |addr|
        addr.type == 'at_praxis'
      }
    end
    def praxis_addresses
      @addresses.select { |addr|
        addr.type == 'at_praxis'
      }
    end
    def work_addresses
      @addresses.select { |addr|
        addr.type == 'at_work'
      }
    end
  end
end
