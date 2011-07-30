require 'rubygems'
require 'linkedin'
require 'linguistics'
require 'ruby-debug'

# Your own creds
require_relative 'creds'


class String
  SPECIAL_STRINGS = %w( founder cto ceo cfo president )

  def cleanup
    gsub(/(-|\r|\n|\.)/, "").strip
  end

  def article
    special? ? "the" : (self[0].downcase =~ /^(a|e|i|o|u)/ ? "an" : "a")
  end

  private
  
  def special?
    SPECIAL_STRINGS.each do |p|
      return true if self.downcase.cleanup == p
    end
    return false
  end
end

class Array
  def conjunct
    ret = self.size > 1 ? (self[0..-2].join(", ") + " and ") : ""
    ret += self.last
  end
end

module TellTale
  
  def self.get_profile(id)
    cl = self.authorize
  end

  def self.get_profile_from_url(url)
    puts "Access #{url}.."
    debugger
    cl = authorize
    fields = %w( first-name last-name headline educations positions specialties twitter-accounts public-profile-url )
    profile = cl.profile(:url => url, :fields => fields)

    File.open("profile-#{ARGV[0]}.yml", "w") do |f|
      Marshal.dump(profile, f) 
    end

    s = Summary.new(profile)
    puts s.summarize
    p
  end

  def self.get_profile_from_file
    s = Summary.new(Marshal.load(File.open("profile-#{ARGV[0]}.yml")))
    puts s.summarize
  end

  def self.authorize
    client = LinkedIn::Client.new(API_KEY, SECRET_KEY)
    rtoken = client.request_token.token
    rsecret = client.request_token.secret

    auth_url = client.request_token.authorize_url

    # XXX Need to fix this for web access
    print "Visit the URL #{auth_url} and gimme the pin: "
    pin = STDIN.gets.strip
    debugger

    key1, key2 = client.authorize_from_request(rtoken, rsecret, pin)
    client.authorize_from_access(key1, key2)
    return client
  end

  class Summary
    include Linguistics::EN
    
    attr_accessor :profile

    def initialize(in_pro)
      @profile = in_pro
    end

    def p; @profile; end

    def educations_summary(level = 0)
      debugger

      if (!p.educations || p.educations.size == 0) 
        return ""
      end

      ret = "#{p.first_name} went to " + 
            p.educations.all.map { |e| EducationSummary.new(e) }.collect(&:summary).conjunct

      ret += ". "
    end

    def contact_details
      return "" if (p.public_profile_url.nil?)

      "#{p.first_name} can be reached " +
       (p.twitter_accounts && p.twitter_accounts.total > 0 ? 
          " on Twitter at #{p.twitter_accounts.all.collect(&:provider_account_name).conjunct}; and " : "") +
       (" on Linkedin at #{p.public_profile_url}")
    end

    # Should this be past positions?
    def positions_summary(level = 0)
      if (!p.positions || p.positions.size == 0) 
        return ""
      end

      ret = ""

      positions = p.positions.all.dup

      # Deal with these later
      founder_positions = positions.select { |x| (x.title && x.title.downcase =~ /founder/) }
      positions -= founder_positions

      # XXX If same as headline, remove
      present = positions.select { |x| x.end_date.nil? }
      if present.any?
        ret += "Currently, #{p.first_name} is "
        ret += present.map { |p| PositionSummary.new(p).summary}.conjunct 
        ret += ". "
      end

      past = positions.select { |x| !x.end_date.nil? }
      if past.any?
        ret += "Prior to this #{p.first_name} was "
        ret += past.map { |p| PositionSummary.new(p).summary }.conjunct
      end

      if founder_positions.any?
        ret += "#{p.first_name} is "
        ret += founder_positions.map { |p| PositionSummary.new(p).summary }.conjunct
      end

      ret += "."
    end

    def specialties_summary
      if (p.specialties && p.specialties.size > 1) 
        "#{p.first_name}'s specialties include " + 
          p.specialties.split("\n").collect(&:cleanup).join(", ") + "."
      else
        ""
      end
    end

    def interests_summary
    end

    def first_line
      ret = "#{p.first_name} #{p.last_name} is " 
      head = p.headline

      debugger

      first_word = head.split(" ").first
      art = first_word.article

      # Cleanup the headline a little more
      if head =~ /\./
        head = head.split(".").conjunct
      end

      ret += "#{art} #{head.cleanup}"
      ret += "." unless ret[-1] == "."

      ret
    end

    def level3
      first_line
    end

    def level2
      first_line + 
        positions_summary + 
        contact_details
    end

    def level1
      first_line + 
        positions_summary + 
        educations_summary + 
        contact_details
    end

    def level0
      # debugger
      first_line + "\n\n" +
        positions_summary + " " +
        specialties_summary + "\n\n" + 
        educations_summary + 
        contact_details
    end

    # level : verbosity level
    #   0 : very very very verbose
    #   1 : very verbose
    #   2 : concise
    #   3 : very_short
    def summarize(level = 0)
      self.send(:"level#{level}")
    end
  end

  # XXX Can use a better name; Summary.summarize? Come on
  class PositionSummary
    attr_accessor :position

    def initialize(p)
      @position = p
    end

    def p; @position; end

    def special?
      SPECIAL_POSITIONS.each do |s|
        return true if p.title.downcase.strip == s
      end
    end

    def special_summary
      case p.title.downcase
      when "founder"
        "the founder of #{p.company.name}"
      when "co-founder"
        "a co-founder of #{p.company.name}"
      end
    end

    # TODO: Include position summary as well? Seems very tough
    # XXX: Lookup company name from nasdaq ticker or something??
    def summary
      "#{title} at #{p.company.name}"
    end

    def title
      if p.title.downcase =~ /(member)|(chair)/ 
        p.title.gsub!(",", " of")
      end
      "#{p.title.article} #{p.title}".squeeze
    end
  end

  class EducationSummary
    attr_accessor :edu, :e

    def initialize(e)
      @edu = @e = e
    end

    def summary
      e.school_name
    end
  end
end

