require 'rubygems'
require 'sinatra'
require 'linkedin'
require "sinatra/reloader" if development?
require 'ruby-debug'

require_relative 'lib/tell_tale'
require_relative 'lib/creds'

enable :sessions, :logging

PROFILE_FIELDS = %w( first-name last-name headline educations positions specialties twitter-accounts public-profile-url interests patents )

def client
  LinkedIn::Client.new(API_KEY, SECRET_KEY) 
end

get "/" do
  if session[:logged_in]
    cl = client
    # debugger
    cl.authorize_from_access(session[:atoken], session[:asecret])
    user = params[:u] || 'srinivt'
    u = "http://linkedin.com/in/#{user}"
  
    u = params[:url] if params[:url]

    @profile = cl.profile(:url => u, :fields => PROFILE_FIELDS)
    @summary = TellTale::Summary.new(@profile).summarize
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
