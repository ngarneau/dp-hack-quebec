require 'sinatra/base'
require 'bundler'
Bundler.require :default

class Listing
  include MongoMapper::Document
  key :code, String
  key :score, Integer
  attr_accessible :score, :code
  validates_uniqueness_of :code
  timestamps!
end

class Listmash < Sinatra::Base

  if ENV['MONGOHQ_URL']
    MongoMapper.connection = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    MongoMapper.database = 'app9579003'
  else
    MongoMapper.connection = Mongo::Connection.new('localhost',27017)
    MongoMapper.database = 'listmash'
  end

  configure do
    set :api_url, 'http://api-beta.duproprio.com/'
    set :username, ENV['API_USER']
    set :userkey, ENV['API_PASS']
    set :appid, '666'
    set :latlongs, [
      {"lat" => "46.819798", "lon" => "-71.225447"}, # quebec
      {"lat" => "46.399988", "lon" => "-72.573349"}, # trois-rivieres
      {"lat" => "45.515971", "lon" => "-73.559372"}, # montreal
      {"lat" => "45.450497", "lon" => "-75.729172"}, # ottawa
      {"lat" => "43.663898", "lon" => "-79.388031"} # toronto
    ]
  end

  # Special route
  not_found do
    @title = "Not found..."
    @message = "Whoops! You requested a route that wasn't available."
    haml :"/error"
  end

  error do
    @title = "Error..."
    @message = "Whoops! Something went wrong..."
    haml :"/error"
  end

  get '/trololo' do
    haml :trololo
  end

  get '/' do
    @sample = settings.latlongs.sample
    response = RestClient.get "#{settings.api_url}GetListingsByCoordinates", {:params =>
      {
        :username => settings.username,
        :userkey => settings.userkey,
        :appid => settings.appid,
        :lang => 'fr',
        :brand => 'dp',
        :lat => @sample["lat"],
        :lon => @sample["lon"],
        :km => '100',
        :minprince => '400000',
        :maxresults => '10',
        :group => 'residential'
      }
    }
    doc = Nokogiri::XML(response)
    listings = Array.new
    doc.xpath('//listingList/listing').map do |i|
      listing = {"code" => i.xpath('code').text, "picture" => i.xpath('photoMainLarge').text}
      listings.push listing
    end

    listings.shuffle
    @listings = listings.shuffle.pop(2)

    haml :index
  end

  post '/' do
    @code = params[:code]
    @listing = Listing.first(:code => @code)
    if @listing.nil?
      newListing = Listing.create(:code => @code, :score => 1)
      newListing.save
    else
      @listing.increment(:score => 1)
    end
    redirect '/'
  end

  get '/ratings' do
    listings = Listing.all(:order => :score.desc)
    listingsToDisplay = Array.new
    listings.each do |listing|
      response = RestClient.get "#{settings.api_url}GetListingPhotos", {:params =>
        {
          :username => settings.username,
          :userkey => settings.userkey,
          :appid => settings.appid,
          :lang => 'fr',
          :brand => 'dp',
          :code => listing["code"]
        }
      }
      doc = Nokogiri::XML(response)
      if @picture = doc.xpath('//photoList/photo/medium')[0].nil?
        p "object is nil"
      else
        @picture = doc.xpath('//photoList/photo/medium')[0].text
        listingToDisplay = {"code" => listing["code"], "picture" => @picture, "score" => listing["score"]}
        listingsToDisplay.push listingToDisplay
      end
    end
    @listingsToDisplay = listingsToDisplay
    haml :ratings
  end

end
