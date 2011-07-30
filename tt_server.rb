require 'rubygems'
require 'sinatra'
require 'linkedin'
require "sinatra/reloader" if development?
require 'ruby-debug'

require_relative 'lib/tell_tale'
require_relative 'lib/creds'

enable :sessions, :logging

PROFILE_FIELDS = %w( first-name last-name headline educations positions specialties twitter-accounts public-profile-url interests patents )

configure do
  set :port, 80
end

def client
  LinkedIn::Client.new(API_KEY, SECRET_KEY) 
end

get "/" do
  if session[:logged_in]
    cl = client
    # debugger
    cl.authorize_from_access(session[:atoken], session[:asecret])
    u = params[:url] if (params[:url] && params[:url] != "")

    @level = (params[:level] || "0").to_i
    if params[:shorten]
      @level += 1
      if @level > 3
        @level = 3
      end
    elsif params[:elongate]
      @level -= 1
      if @level < 0 
        @level = 0
      end
    end

    opts = { :fields => PROFILE_FIELDS }
    opts[:url] = u if u
    @url = opts[:url]
    
    @profile = cl.profile(opts)
    @summary = TellTale::Summary.new(@profile)

    erb :bio
  else
    erb :home
  end
end

get "/login" do
=begin
  print "here\n"
  rtok, rsec, auth_url = TellTale::authorize_web(cb)
  session[:rtoken] = rtok
  session[:rsecret] = rsec
  redirect auth_url
=end
  cb = "http://#{request.host_with_port}/auth/callback"
  cl = client
  req_token = cl.request_token(:oauth_callback => cb)
  session[:rtoken] = req_token.token
  session[:rsecret] = req_token.secret
  redirect cl.request_token.authorize_url
end

get "/logout" do
  session[:logged_in] = session[:atoken] = session[:asecret] = nil
  redirect "/"
end

get "/auth/callback" do
  cl = client
  if session[:atoken].nil?
    pin = params[:oauth_verifier]
    atoken, asecret = cl.authorize_from_request(session[:rtoken], session[:rsecret], pin)
    session[:atoken] = atoken
    session[:asecret] = asecret
    cl.authorize_from_access(atoken, asecret)
  else
    cl.authorize_from_access(session[:atoken], session[:asecret])
  end
  session[:logged_in] = true
  profile = cl.profile
  session[:user_name] = profile.first_name
  redirect "/"
end
