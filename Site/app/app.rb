# encoding: utf-8

require 'sinatra'
require 'geoip'
require 'logger'
require 'haml'
require 'sass'
require 'rdiscount'
require_relative "../lib/ext/Array.rb"
require_relative "../lib/ext/Hash.rb"

class GeoIPalize < Sinatra::Base
  
  ROOT = File.dirname(__FILE__) 
  Assets = File.expand_path( File.join ROOT, "../", "assets" )
  Views = File.expand_path( File.join ROOT, "../", "views" )
  Public = File.join Assets, "public"
  Log   = File.join( ROOT, "../", "log", "app.log" )
  DB = GeoIP.new('/usr/local/share/GeoIP/GeoLiteCity.dat')
  
  configure do
    set :root, ROOT
    set :public, Public
    set :views, Views    

    logger = Logger.new STDOUT
    logger.level = Logger::DEBUG
    logger.datetime_format = '%a %d-%m-%Y %H%M '
    set :logger, logger

    set :haml, { :ugly=>true }
  end
  
  LogfileRegex = /^
                  (\d[\d|\.]+)   # ip
                  \s\-\s\-\s     # username
                  \[([^\]]+)\]\s # timestamp
                  ([^\s]+)\s   # access request type e.g. GET
                  ([^\s]+)\s     # page
                  (?:[^\s]+)\s   # HTTP version or whatnot
                  "(\d+)"        # status code
                 /x
  
  Log_record = Struct.new( :ip, :timestamp, :access_request_type, :page, :status_code )
  
  LOGFILES = "/var/log/nginx/"
  
  get "/:logfile" do |logfile|
    output = ""
    halt if logfile.match %r{/|\\}
    logfile.gsub! /[^\w\.\-]/, '_'
    halt unless logfile.match /\.log$/
    logfile = File.join LOGFILES, logfile
    lines = File.readlines(logfile, :encoding => "UTF-8" ).reverse
    
    ips = { }
    lines.each do |line|
      match = line.match( LogfileRegex)
      if match.nil?
        output << "Couldn't match:\n\t#{line}\n<hr>\n\n"
      else
        record = Log_record.new( *match.captures )
        if ips.has_key? record.ip 
          ips[record.ip][:visits] += 1
        else
          ips[record.ip] = {visits: 1, last_visit: record.timestamp, records: []}
        end
        ips[record.ip][:records] << record
      end
    end
    
    ips = ips.each_with_object({}) do |(k, v), h|
      geo = DB.city( k ) 
      h[k] = geo.nil? ? v : v.merge( {geo: geo } )
    end
    # ips.merge(ips) do |k,v, new_v|
    #   geo = DB.city( k ) 
    #   ips[k][:geo] = geo unless geo.nil?
    # end
      # output << "\n\n\tPages:\n"
      # output << v[:records].reduce("") do |mem, record|
      #   mem + "#{record.timestamp} #{record.access_request_type} #{record.page} #{record.status_code}\n"
      # end

    output << partial( :ip, collection: ips )
    output << partial(:main, :locals =>{ output: output } )
    
    haml :content, :locals => { output: output  }
  end # get


  get '/stylesheet.css' do
    scss :style
  end
  
  
  helpers do
    # support for partials
    # @example
    #   partial( :meta, :locals => {meta: meta} )
    def partial(template, *args)
      opts = args.extract_options! # get hash options if they're there
      opts.merge!(:layout => false) # don't layout, this is a partial

      if collection = opts.delete(:collection)
        options.logger.debug "#{template} with COLLECTION!"
        collection.inject([]) do |buffer, member|
          buffer << haml(template, opts.merge(
            :layout => false, 
            :locals => {template.to_sym => member}
            )
          )
        end.join("\n")
      else
        options.logger.debug "#{template} with NO COLLECTION!"
        haml(template, opts)
      end
    end # def
    
  end # helpers
  
  
end