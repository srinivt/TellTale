require 'rubygems'
require 'linkedin'

# Your own creds
require_relative 'creds'

class NilClass
  def blank?
    return true
  end
end

class String
  SPECIAL_STRINGS = %w( founder cto ceo cfo president )

  def cleanup
    gsub(/(-|\r|\n|\.)/, "").strip
  end

  def blank?
    self.strip == ""
  end

  def article
    sp = self.split(" ")
    if sp.size > 1
      return sp.first.article
    else
      special? ? "the" : (self[0].downcase =~ /^(a|e|i|o|u)/ ? "an" : "a")
    end
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
    cl = authorize_cli
    fields = %w( first-name last-name headline educations positions specialties twitter-accounts public-profile-url interests patents )
    profile = cl.profile(:url => url, :fields => fields)

    File.open("profile-#{ARGV[0]}.yml", "w") do |f|
      Marshal.dump(profile, f) 
    end

    s = Summary.new(profile)
    puts s.summarize(ARGV[1] || 0)
    p
  end

  def self.get_profile_from_file
    s = Summary.new(Marshal.load(File.open("profile-#{ARGV[0]}.yml")))
    debugger
    puts s.summarize(ARGV[1] || 0)
  end

  def self.ll_client
    LinkedIn::Client.new(API_KEY, SECRET_KEY)
  end

  def self.get_auth_client(key1, key2)
    client = self.ll_client
    client.authorize_from_access(key1, key2)
    return client
  end

  def self.authorize_web(callback)
    client = self.ll_client
    req_token = client.request_token(:oauth_callback => callback)
    rtoken = req_token.token
    rsecret = req_token.secret
    auth_url = client.request_token.authorize_url

    return [rtoken, rsecret, auth_url]
  end

  def self.authorize_cli
    client = self.ll_client
    rtoken = client.request_token.token
    rsecret = client.request_token.secret

    auth_url = client.request_token.authorize_url

    system "firefox #{auth_url}"

    # XXX Need to fix this for web access
    print "Visit the URL #{auth_url} and gimme the pin: "
    pin = STDIN.gets.strip

    key1, key2 = client.authorize_from_request(rtoken, rsecret, pin)
    client.authorize_from_access(key1, key2)
    return client
  end

  class Summary
    
    attr_accessor :profile, :level

    def initialize(in_pro)
      @profile = in_pro
      @level = 0
    end

    def p; @profile; end

    def educations_summary(level = 0)
      if (!p.educations || p.educations.size == 0) 
        return ""
      end

      eds = p.educations
      all_degrees = true
      eds.each { |e| all_degrees &&= (e.degree && !e.degree.blank?) }

      ret = all_degrees ? "#{first_name} holds " : "#{first_name} went to "
      ret += p.educations.map { |e| EducationSummary.new(e, all_degrees) }.collect(&:summary).conjunct

      ret += ". "
    end

    def contact_details
      return "" if (p.public_profile_url.nil?)

=begin
      "#{first_name} can be reached " +
       (p.twitter_accounts && p.twitter_accounts.total > 0 ? 
          " on Twitter at #{p.twitter_accounts.collect(&:provider_account_name).conjunct}; and " : "") +
=end
      
       "#{first_name} can be reached " +
       (" on Linkedin at #{p.public_profile_url}")
    end

    # Should this be past positions?
    def positions_summary(level = 0)
      if (!p.positions || p.positions.size == 0) 
        return ""
      end

      ret = ""

      positions = p.positions.dup

      # Deal with the past founder positions
      founder_positions = positions.select { |x| (x.title && x.title.downcase =~ /founder/ && !x.is_current) }
      positions -= founder_positions

      # XXX If same as headline, remove
      present = positions.select { |x| x.is_current == 'true' }
      if present.any?
        ret += "Currently, " if render_headline?
        ret += "#{first_name} is "
        ret += present.map { |p| PositionSummary.new(p).summary}.conjunct 
        ret += ". "
      end

      past = positions.select { |x| x.is_current == 'false' }
      if past.any?
        ret += "Prior to this #{first_name} was "
        ret += past.map { |p| PositionSummary.new(p).summary }.conjunct
      end

      if founder_positions.any?
        ret += "#{first_name} is "
        ret += founder_positions.map { |p| PositionSummary.new(p).summary }.conjunct
      end

      ret += "."
    end

    def specialties_summary
      if (p.specialties && p.specialties.size > 1) 
        "#{first_name}'s specialties include " + 
          p.specialties.split("\n").collect(&:cleanup).join(", ") + ". "
      else
        ""
      end
    end

    def interests_summary
      return "" if p.interests.blank?
      "#{first_name} is intersted in #{p.interests.split(',').conjunct}. "
    end

    def first_name 
      p.first_name
    end

    def first_position
      return "" if (!p.positions || p.positions[0].nil?)
      first = p.positions[0]
      "#{first.title} at #{first.company.name}"
    end

    def render_headline?
      p.headline != first_position
    end

    def first_line
      return "" unless render_headline?

      return first_line!
    end

    def first_line! 
      ret = "#{first_name} #{p.last_name} is " 
      head = p.headline

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
      first_line!
    end

    def level2
      first_line + "\n\n" +
        positions_summary + "\n\n" +  
        contact_details
    end

    def level1
      first_line + "\n\n" 
        positions_summary +  " " + 
        educations_summary + "\n\n" +
        contact_details
    end

    def level0
      first_line + "\n\n" +
        positions_summary + " " +
        specialties_summary + interests_summary + "\n\n" + 
        educations_summary + "\n\n" + 
        contact_details
    end

    # level : verbosity level
    #   0 : very very very verbose
    #   1 : very verbose
    #   2 : concise
    #   3 : very_short
    def summarize(l = 0)
      @level = l
      self.send(:"level#{l}")
    end
  end

  # XXX Can use a better name; Summary.summarize? Come on
  class PositionSummary
    attr_accessor :position

    def initialize(p)
      @position = p
    end

    def p; @position; end

    # TODO: Include position summary as well? Seems very tough
    # XXX: Lookup company name from nasdaq ticker or something??
    def summary
      "#{title} at #{p.company.name}"
    end

    def title
      if p.title.downcase =~ /(member)|(chair)/ 
        p.title.gsub!(",", " of")
      end
      "#{p.title.article} #{p.title}"
    end
  end

  class EducationSummary
    attr_accessor :edu, :e, :with_degrees

    def initialize(e, degrees)
      @edu = @e = e
      @with_degrees = degrees
    end

    def summary
      if with_degrees 
        ret = "#{degree} "
        ret += "in #{e.field_of_study} " unless e.field_of_study.blank?
        ret += "from #{e.school_name}"
      else
        e.school_name
      end
    end

    def degree
      return "" if (!e.degree || e.degree.blank?)

      if e.degree.downcase =~ /^b/
        return "bachelors"
      end

      return e.degree
    end
  end
end

