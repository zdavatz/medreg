#!/usr/bin/env ruby
# encoding: utf-8

require 'medreg/address'
require 'medreg/ba_type'
module Medreg
  class Company
    attr_accessor :address_email, :business_area, :business_unit, :cl_status,
      :competition_email, :complementary_type, :contact, :deductible_display,
      :disable_patinfo, :ean13, :generic_type, :addresses,
      :invoice_htmlinfos, :logo_filename, :lookandfeel_member_count, :name,
      :powerlink, :regulatory_email, :swissmedic_email, :swissmedic_salutation,
      :url, :ydim_id, :limit_invoice_duration, :force_new_ydim_debitor,
      :narcotics
    attr_reader :disabled_invoices
    alias :fullname :name
    alias :power_link= :powerlink=
    alias :power_link :powerlink
    alias :to_s :name
    alias :email :address_email
    def initialize
      @addresses = [Address2.new]
    end
    def is_pharmacy?
      case @business_area
        when BA_type::BA_public_pharmacy, BA_type:: BA_hospital_pharmacy
          return true
        else
          false
        end
    end
  end
end
