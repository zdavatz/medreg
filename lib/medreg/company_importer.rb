#!/usr/bin/env ruby
# encoding: utf-8

require 'medreg/address'
require 'medreg/ba_type'
require 'medreg/company'
require 'medreg/resilient_loop'
require 'rubyXL'
require 'mechanize'
require 'logger'
require 'cgi'
require 'psych' if RUBY_VERSION.match(/^1\.9/)
require "yaml"

module Medreg
  DebugImport           = defined?(Minitest) ? true : false
  BetriebeURL         = 'https://www.medregbm.admin.ch/Betrieb/Search'
  BetriebeXLS_URL     = "https://www.medregbm.admin.ch/Publikation/CreateExcelListBetriebs"
  RegExpBetriebDetail = /\/Betrieb\/Details\//
  TimeStamp            = Time.now.strftime('%Y.%m.%d')
  Companies_curr      = File.join(ARCHIVE_PATH, "companies_#{TimeStamp}.xlsx")
  Companies_YAML      = File.join(ARCHIVE_PATH, "companies_#{TimeStamp}.yaml")
  Companies_CSV       = File.join(ARCHIVE_PATH, "companies_#{TimeStamp}.csv")
  CompanyInfo = Struct.new("CompanyInfo",
                          :gln,
                          :exam,
                          :address,
                          :name_1,
                          :name_2,
                          :addresses,
                          :plz,
                          :canton_giving_permit,
                          :country,
                          :company_type,
                          :drug_permit,
                          )
#    GLN Person  Name  Vorname PLZ Ort Bewilligungskanton  Land  Diplom  BTM Berechtigung  Bewilligung Selbstdispensation  Bemerkung Selbstdispensation

  COMPANY_COL = {
    :gln                  => 0, # A
    :name_1               => 1, # B
    :name_2               => 2, # C
    :street               => 3, # D
    :street_number        => 4, # E
    :plz                  => 5, # F
    :locality             => 6, # G
    :canton_giving_permit => 7, # H
    :country              => 8, # I
    :company_type         => 9, # J
    :drug_permit          => 10, # K
  }
  class CompanyImporter
    RECIPIENTS = []

    def save_for_log(msg)
      Medreg.log(msg)
      withTimeStamp = "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}: #{msg}"
      @@logInfo << withTimeStamp
    end
    def initialize(glns_to_import = [])
      @glns_to_import = glns_to_import.clone
      @glns_to_import.delete_if {|item| item.size == 0}
      @info_to_gln    = {}
      @@logInfo       = []
      FileUtils.rm_f(Companies_YAML) if File.exists?(Companies_YAML)
      @yaml_file      = File.open(Companies_YAML, 'w+')
      @companies_prev_import = 0
      @companies_created = 0
      @companies_skipped = 0
      @companies_deleted = 0
      @archive = ARCHIVE_PATH
      @@all_companies    = {}
      setup_default_agent
    end
    def save_import_to_csv(filename)
      def add_item(info, item)
        info << item.to_s.gsub(',',' ')
      end
      field_names = ["ean13",
                "name",
                "plz",
                "location",
                "address",
                "ba_type",
                "narcotics",
                "address_additional_lines",
                "address_canton",
                "address_fax",
                "address_fon",
                "address_location",
                "address_type",
                ]
      CSV.open(filename, "wb") do |csv|
        csv << field_names
        @@all_companies.each{ |gln, person|
                            maxlines = 1
                            maxlines = person[:addresses].size if person[:addresses].size > maxlines
                            0.upto(maxlines-1).
                          each{
                               |idx|
                                info = []
                                field_names[0..6].each{ |name| add_item(info, eval("person[:#{name}]")) }
                                address = person[:addresses][idx]
                                field_names[7..-1].each{ |name| add_item(info, eval("x = address.#{name.sub('address_','')}; x.is_a?(Array) ? x.join(\"\n\") : x")) } if address
                                csv << info
                              }
                          }
      end
    end
    def save_import_to_yaml(filename)
      File.open(filename, 'w+') {|f| f.write(@@all_companies.to_yaml) }
      save_for_log "Saved #{@@all_companies.size} companies in #{filename}"
    end
    def update
      saved = @glns_to_import.clone
      r_loop = ResilientLoop.new(File.basename(__FILE__, '.rb'))
      @state_yaml = r_loop.state_file.sub('.state', '.yaml')
      if File.exist?(@state_yaml) and File.size(@state_yaml) > 10
        @@all_companies = YAML.load_file(@state_yaml)
        @companies_prev_import = @@all_companies.size
        puts "Got #{@companies_prev_import} items from previous import saved in #{@state_yaml}"
      end
      latest = get_latest_file
      save_for_log "parse_xls #{latest} specified GLN ids #{saved.inspect}"
      parse_xls(latest)
      @info_to_gln.keys
      get_detail_to_glns(saved.size > 0 ? saved : @glns_to_import)
      save_import_to_yaml(Companies_YAML)
      save_import_to_csv(Companies_CSV)
      return @companies_created, @companies_prev_import, @companies_deleted, @companies_skipped
    ensure
      if @companies_created > 0
        save_import_to_yaml(@state_yaml)
        save_import_to_csv(@state_yaml.sub('.yaml','.csv'))
      end
    end
    def setup_default_agent
      @agent = Mechanize.new
      @agent.user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:31.0) Gecko/20100101 Firefox/31.0 Iceweasel/31.1.0'
      @agent.redirect_ok         = :all
      @agent.follow_meta_refresh_self = true
      @agent.follow_meta_refresh = :everwhere
      @agent.redirection_limit   = 55
      @agent.follow_meta_refresh = true
      @agent.ignore_bad_chunking = true
      @agent
    end
    def parse_details(html, gln)
      left = html.at('div[class="colLeft"]').text
      right = html.at('div[class="colRight"]').text
      btm = html.at('div[class="twoColSpan"]').text
      infos = []
      infos = left.split(/\r\n\s*/)
      unless infos[2].eql?(gln.to_s)
        Medreg.log "Mismatch between searched gln #{gln} and details #{infos[2]}"
        return nil
      end
      company = Hash.new
      company[:ean13] =  gln.to_s.clone
      company[:name] =  infos[4]
      idx_plz     = infos.index("PLZ \\ Ort")
      idx_canton  = infos.index('Bewilligungskanton')
      address = infos[6..idx_plz-1].join(' ')
      company[:plz] = infos[idx_plz+1]
      company[:location] = infos[idx_plz+2]
      idx_typ = infos.index('Betriebstyp')
      ba_type = infos[idx_typ+1]
      company[:address] = address
      company[:ba_type] = ba_type
      company[:narcotics] = btm.split(/\r\n\s*/)[-1]
      update_address(company)
      Medreg.log company if $VERBOSE
      company
    end
    Search_failure = 'search_took_to_long'
    def get_detail_to_glns(glns)
      r_loop = ResilientLoop.new(File.basename(__FILE__, '.rb'))
      failure = 'Die Personensuche dauerte zu lange'
      idx = 0
      max_retries = 3
      Medreg.log "get_detail_to_glns for #{glns.size} glns. first 10 are #{glns[0..9]} state_id is #{r_loop.state_id.inspect}" if DebugImport
      glns.each { |gln|
        idx += 1
        if r_loop.must_skip?(gln)
          Medreg.log "Skipping #{gln}. Waiting for #{r_loop.state_id.inspect}" if DebugImport
          next
        end
        nr_tries = 0
        success = false
        while nr_tries < max_retries  and not success
          begin
            r_loop.try_run(gln, defined?(Minitest) ? 500 : 5 ) do
              Medreg.log "Searching for company with GLN #{gln}. Created #{@companies_created}. At #{@companies_created+@companies_prev_import} of #{glns.size}.#{nr_tries > 0 ? ' nr_tries is ' + nr_tries.to_s : ''}"
              page_1 = @agent.get(BetriebeURL)
              raise Search_failure if page_1.content.match(failure)
              hash = [
            ['Betriebsname', ''],
            ['Plz', ''],
            ['Ort', ''],
            ['GlnBetrieb', gln.to_s],
            ['BetriebsCodeId', '0'],
            ['KantonsCodeId', '0'],
              ]
              res_2 = @agent.post(BetriebeURL, hash)
              if res_2.link(:href => RegExpBetriebDetail)
                page_3 = res_2.link(:href => RegExpBetriebDetail).click
                raise Search_failure if page_3.content.match(failure)
                company = parse_details(page_3, gln)
                store_company(company)
                @@all_companies[gln] =  company
              else
                Medreg.log "could not find gln #{gln}"
                @companies_skipped += 1
              end
              success = true
            end
          rescue Timeout => e
            nr_tries += max_retries  if defined?(MiniTest)
            Medreg.log "rescue #{e} will retry #{max_retries - nr_tries} times"
            nr_tries += 1
            sleep defined?(MiniTest) ? 0.01 : 60
          end
          if (@companies_created + @companies_prev_import) % 100 == 99
            Medreg.log "Start saving after #{@companies_created} created #{@companies_prev_import} from previous import"
          end
        end
      }
      r_loop.finished
    ensure
      Medreg.log "Start saving"
      Medreg.log "Finished"
    end
    def get_latest_file
      agent = Mechanize.new
      target = Companies_curr
      needs_update = true
      return target if File.exist?(target)
      file = agent.get(BetriebeXLS_URL)
      download = file.body
      File.open(target, 'w+') { |f| f.write download }
      save_for_log "saved #{file.body.size} bytes as #{target}"
      target
    end
    def report
      report = "Companies update \n\n"
      report << "New companies: "       << @companies_created.to_s << "\n"
      report << "Companies from previous imports: "   << @companies_prev_import.to_s << "\n"
      report << "Deleted companies: "   << @companies_deleted.to_s << "\n"
      report
    end
    def update_address(data)
      addr = Address2.new
      addr.name    =  data[:name  ]
      addr.address =  data[:address]
      # addr.additional_lines = [data[:address] ]
      addr.location = [data[:plz], data[:location]].compact.join(' ')
      if(fon = data[:phone])
        addr.fon = [fon]
      end
      if(fax = data[:fax])
        addr.fax = [fax]
      end
      data[:addresses] = [addr]
    end
    def store_company(data)
      @companies_created += 1
      company = Company.new
      action = 'create'
      ba_type = nil
      case  data[:ba_type]
        when /kantonale Beh/i
          ba_type = Medreg::BA_type::BA_cantonal_authority
        when /ffentliche Apotheke/i
          ba_type = Medreg::BA_type::BA_public_pharmacy
        when /Spitalapotheke/i
          ba_type = Medreg::BA_type::BA_hospital_pharmacy
        when /wissenschaftliches Institut/i
          ba_type = Medreg::BA_type::BA_research_institute
        else
          ba_type = 'unknown'
      end
      company.ean13         = data[:ean13]
      company.name          = data[:name]
      company.business_area = ba_type
      company.narcotics     = data[:narcotics]
      company.addresses     = data[:addresses]
      Medreg.log "store_company updated #{data[:ean13]} database. ba_type #{ba_type}." if $VERBOSE
    end
    def parse_xls(path)
      Medreg.log "parsing #{path}"
      workbook = RubyXL::Parser.parse(path)
      positions = []
      rows = 0
      workbook[0].each do |row|
        next unless row and (row[COMPANY_COL[:gln]] or row[COMPANY_COL[:name_1]])
        rows += 1
        if rows > 1
          info = CompanyInfo.new
          [:gln, :name_1, :name_2, :plz, :canton_giving_permit, :country, :company_type,:drug_permit].each {
            |field|
            cmd = "info.#{field} = row[COMPANY_COL[#{field.inspect}]] ? row[COMPANY_COL[#{field.inspect}]].value : nil"
            eval(cmd)
          }
          @info_to_gln[ row[COMPANY_COL[:gln]] ? row[COMPANY_COL[:gln]].value : row[COMPANY_COL[:name_1]].value ] = info
        end
      end
      @glns_to_import = @info_to_gln.keys.sort.uniq
    end
    def CompanyImporter.all_companies
      @@all_companies
    end
  end
end
