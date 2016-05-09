require 'open-uri'
require 'byebug'

module Behaviour
  def self.config
    @@config
  end

  # This table specifies matchers and handlers. The first matching row will be run.
  @@config = 
  [
    [ /(hi|hello|howdy)/, :say_hi ],
    [ "time", :say_time ],
    [ /gif/, :serve_a_gif ],
    [ /weather/, :say_the_forecast ],
    [ ->(text){ true }, :say_wat? ]
  ]

  module Handlers
    # Why should we do this?
    # Why shouldn't we do this?
    @@weather_token = '83658a490b36698e09e779d265859910'
    @@giphy_token = 'dc6zaTOxFJmzC'

    def say_hi(data)
      message channel: data.channel, text: "Hi <@#{data.user}>!"
    end

    def say_wat?(data)
      message channel: data.channel, text: "Sorry <@#{data.user}>, what?"
    end

    def say_time(data)
      message channel: data.channel, text: "It is now #{Time.now.strftime("%l:%M %P").strip}"
    end

    def serve_a_gif(data)
      query = data.text.sub(/gif/,"").strip
      uri = URI.parse("http://api.giphy.com/v1/gifs/random?api_key=#{@@giphy_token}&tag=#{URI.escape(query)}")
      begin
        response = JSON.parse(uri.read)["data"]
        if response.empty?
          response = "I didn't find anything. https://media.giphy.com/media/PgbXsiT0EVuta/200_d.gif"
        else
          response = response["fixed_height_downsampled_url"]
        end
      rescue Exception => e
        response = "Oops. https://media.giphy.com/media/AmT7Raa4GJQsM/200_d.gif"
      end
      message channel: data.channel, text: response
    end

    def say_the_forecast(data)
      uri = URI.parse("http://api.openweathermap.org/data/2.5/weather?APPID=#{@@weather_token}&q=#{URI.escape(data.text)}") 
      begin
        weather = JSON.parse(uri.read)
        location = weather["name"]
        temp = (weather["main"]["temp"]-273.15).round(1) # temp is in Kelvin! LOL
        response = "It is currently #{temp}C in #{location}"
      rescue
        response = "Oops, my weather feed is down. Check CP24. :stuck_out_tongue_winking_eye:"
      end
      message channel: data.channel, text: response
    end
  end
end
