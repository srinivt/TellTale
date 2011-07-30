require 'rubygems'
require 'linkedin'
require 'linguistics'
require 'ruby-debug'

# Your own creds
require_relative 'creds'

module TellTale
  
  def self.get_profile(id)
    cl = self.authorize
  end

  def self.get_profile_from_url(url)
    cl = authorize
    fields = %w( first-name last-name headline educations positions )
    profile = cl.profile(:url => url, :fields => fields)

    s = Summary.new(profile)
    puts s.summarize
    p
  end

  def self.authorize
    client = LinkedIn::Client.new(API_KEY, SECRET_KEY)
    rtoken = client.request_token.token
    rsecret = client.request_token.secret

    auth_url = client.request_token.authorize_url

    # XXX Need to fix this for web access
    print "Visit the URL #{auth_url} and gimme the pin: "
    pin = gets.strip

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

    def educations_summary
      ""
    end

    def contact_details
      ""
    end

    # Should this be past positions?
    def positions_summary
      ret = "\nPrior to this #{p.first_name} was "

      # XXX: Lookup company name from nasdaq ticker or something??
      p_strs = p.positions.all[1..-1].map do |p|
        "#{p.title} at #{p.company.name}"
      end

      ret += Linguistics::EN::conjunction(p_strs);
      ret += ".\n"
    end

    def specialities_summary
      ""
    end

    def first_line
      "#{p.first_name} #{p.last_name} is the #{p.headline}\n" 
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
      first_line + 
        positions_summary + 
        specialities_summary + 
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

  class PositionSummary
    attr_accessor :position

    def initialize(p)
    end
  end

  class EducationSummary
  end
end

