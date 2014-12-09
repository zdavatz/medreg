  #!/usr/bin/env ruby
# encoding: utf-8

module Medreg
  class Address2 # copied from oddb
    @@city_pattern = /[^0-9]+[^0-9\-](?!-)([0-9]+)?/u
    attr_accessor :name, :additional_lines, :address, :location, :title, :fon, :fax, :canton, :type
    alias :address_type :type
    def initialize
      super
      @additional_lines = []
      @fon = []
      @fax = []
    end
    def city
      @location
      if(match = @@city_pattern.match(@location.to_s))
         match.to_s.strip
      end
    end
    def lines
      lines = lines_without_title
      if(!@title.to_s.empty?)
        lines.unshift(@title)
      end
      lines
    end
    def lines_without_title
      ([
        @name,
      ] + @additional_lines +
      [
        @address,
        location_canton,
      ]).delete_if { |line| line.to_s.empty? }
    end
    def location_canton
      if(@canton && @location)
        @location + " (#{@canton})"
      else
        @location
      end
    end
    def number
      if(match = /[0-9][^\s,]*/u.match(@address.to_s))
        match.to_s.strip
      elsif @additional_lines[-1]
        @additional_lines[-1].split(/\s/)[-1]
      end
    end
    def plz
      if(match = /[1-9][0-9]{3}/u.match(@location.to_s))
         match.to_s
      end
    end
    def street
      if(match = /[^0-9,]+/u.match(@address.to_s))
        match.to_s.strip
      elsif @additional_lines[-1]
        @additional_lines[0].split(/\s/)[0]
      end
    end
    def <=>(other)
      self.lines <=> other.lines
    end
  end
end