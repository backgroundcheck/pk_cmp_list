require 'scraperwiki'
# encoding: UTF-8
require 'nokogiri'
require 'mechanize'
# TODO:
# 1. Fork the ScraperWiki library (if you haven't already) at https://classic.scraperwiki.com/scrapers/mcf/
# 2. Add the forked repo as a git submodule in this repo
# 3. Change the line below to something like require File.dirname(__FILE__) + '/mcf/scraper'
# 4. Remove these instructions
require 'scrapers/mcf'

Mechanize.html_parser = Nokogiri::HTML

BASE_URL = "http://www.secp.gov.pk/ns/"

@br = Mechanize.new { |b|
  b.user_agent_alias = 'Linux Firefox'
  b.read_timeout = 1200
  b.max_history=0
  b.retry_change_requests = true
  b.verify_mode = OpenSSL::SSL::VERIFY_NONE
}

class String
  def pretty
    self.gsub(/^,|,$/,'').strip
  end
end

def scrape(pg,act,rec)
  data = pg.body
  if act == "list"
    records = []
    Nokogiri::HTML(data).xpath(".//td[@valign='top']/table[@class='text']/tr[td]").each{|tr|
      td = tr.xpath("td")
      records << {
        "tmp_url" => BASE_URL + attributes(td[0].xpath("./a"),"href")
      }
    }
    return records
  elsif act == "old_details"
    r = {"doc"=>Time.now,"link"=>pg.uri.to_s}
    doc = Nokogiri::HTML(data).xpath(".//table[@class='linkmain']/tr")
    r["company_name"] = s_text(doc.xpath(".//td[normalize-space(text())='Name']/following-sibling::*[1][self::td]/b/text()"))
    r["company_number"] = s_text(doc.xpath(".//td[normalize-space(text())='Registration #']/following-sibling::*[1][self::td]/b/text()"))
    r["incorporated"] = s_text(doc.xpath(".//td[normalize-space(text())='Registration Date']/following-sibling::*[1][self::td]/b/text()"))
    r["old_company_number"] = s_text(doc.xpath(".//td[normalize-space(text())='Old Registration #']/following-sibling::*[1][self::td]/b/text()"))
    r["cro"] = s_text(doc.xpath(".//td[normalize-space(text())='CRO']/following-sibling::*[1][self::td]/b/text()"))
    
    return r unless r["company_name"].nil? or r["company_name"].empty? 
  elsif act == "details"
    doc = Nokogiri::HTML(data).xpath(".//table[@class='linkmain']")
    r = {}

    r["company_name"] = a_text(doc.xpath("./tr/td[text()='Name']/following-sibling::*[1][self::td]")).join("\n").strip
    r["status"] = a_text(doc.xpath("./tr/td[text()='Status']/following-sibling::*[1][self::td]")).join("\n").strip
    r["company_number"] = a_text(doc.xpath("./tr/td[text()='CUIN']/following-sibling::*[1][self::td]")).join("\n").strip
    r["old_company_number"] = a_text(doc.xpath("./tr/td[text()='Old CUIN']/following-sibling::*[1][self::td]")).join("\n").strip
    r["registration_dt"] = a_text(doc.xpath("./tr/td[text()='Registration Date']/following-sibling::*[1][self::td]")).join("\n").strip
    r["cro"] = a_text(doc.xpath("./tr/td[text()='CRO']/following-sibling::*[1][self::td]")).join("\n").strip
    tmp = a_text(doc.xpath("./tr/td[text()='Form A/B Made upto date']/following-sibling::*[1][self::td]")).join("\n").strip
    r["form_dt"] = (tmp.nil? or tmp.empty? or tmp == 'none')? nil : tmp
    r["mandatory_filing"] = a_text(doc.xpath("./tr/td[text()='Mandatory Filing']/following-sibling::*[1][self::td]")).join("\n").strip
    return r.merge(rec)
  end
end

start = get_metadata("start",85660)
(start..start+50).each{|id|
  begin
    pg = @br.get("http://www.secp.gov.pk/ns/company.asp?COMPANY_CODE=#{'%07d' % id}&id=") rescue nil
    next if pg.nil? 
    r = scrape(pg,"details",{"doc"=>Time.now})
    ScraperWiki.save_sqlite(['company_number'],r,"ocdata")
    save_metadata("start",id)
    sleep(3)
  end
}