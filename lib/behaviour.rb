require 'slack'
require 'open-uri'
require 'byebug'
require 'wolfram'
require "pry"

module Behaviour
  def self.config
    @@config
  end

  # This table specifies matchers and handlers. The first matching row will be run.
  @@config =
  [
    [ /\b(hi|hello|howdy)\b/, :say_hi ],
    [ "time", :say_time ],
    [ /\bgif\b/, :serve_a_gif ],
    [ /\b(question)\b/, :ask_a_question],
    [ /\b(what|who|where)\b/, :say_correct],
    [ /\b(give up)\b/, :give_up],
    [ -> msg { msg =~ /\b(weather|temperature)\b/ }, :say_current_temp ],
    [ -> _ { !Wolfram.appid.nil? }, :wolfram_alpha_search ],
    [ ->(text){ true }, :say_wat? ]
  ]

  module Handlers
    # Why should we do this?
    # Why shouldn't we do this?
    @@weather_token = '83658a490b36698e09e779d265859910'
    @@giphy_token = 'dc6zaTOxFJmzC'
    Wolfram.appid = 'Y8UT34-HJAWGP6J7R'
    @jeopardy_answer = 'the answer'
    @current_question = nil

    def say_hi(data)
      message channel: data.channel, text: "Hi <@#{data.user}>! :wave:"
    end

    def ask_a_question(data)
      uri = URI.parse("http://jservice.io/api/random")
      if @current_question
        question = @current_question['question']
        topic = @current_question['category']['title']
        message channel: data.channel, text: ("The current question is: \nCategory: #{topic} \nQuestion: #{question}")
      else
        begin
          response = JSON.parse(uri.read)[0]
        rescue
          @current_question = nil
          response = "The api didn't give me a question.  Totally not my fualt."
        end
        @current_question = response
        question = response['question']
        topic = response['category']['title']
        answer = response['answer']
        message channel: data.channel, text: ("Category: #{topic} \nQuestion: #{question}")
        @answer = answer
    end
  end

    def say_correct(data)
      if data.text.downcase.include?(@answer.downcase) && @current_question
        message channel: data.channel, text: "Great!.  <@#{data.user}> got the last question right!  The Answer was #{@answer}"
        @current_question = nil
      else
        wolfram_alpha_search(data)
      end

    end

    def give_up(data)
      if @current_question
        @current_question = nil
      end
      message channel: data.channel, text: "The answer to the last question was #{@answer}"
    end

    def say_wat?(data)
      message channel: data.channel, text: "Sorry <@#{data.user}>, what:question:"
    end

    def say_time(data)
      response = [ "It is now #{Time.now.strftime("%l:%M %P").strip}", "The time is currently #{Time.now.strftime("%l:%M %P").strip}", "I've got #{Time.now.strftime("%l:%M %P").strip}" ].sample
      message channel: data.channel, text: response
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
          response = "LOL. I can't stop laughing at this one. #{response}" if rand < 0.1 # add with 1/10 frequency
        end
      rescue Exception => e
        response = "Oops. https://media.giphy.com/media/AmT7Raa4GJQsM/200_d.gif"
      end
      message channel: data.channel, text: response
    end

    def wolfram_alpha_search(data)
      begin
        typing channel: data.channel

        query  = data.text.sub("wolfram", "").strip
        result = Wolfram.fetch(query)
        hash   = Wolfram::HashPresenter.new(result).to_hash

        image_urls = result.pods.map { |p| p.img["src"] }

        data_attachments =
          hash[:pods]
            .except("Images", "Image")
            .reject { |_, text| text.empty? || text.first.empty? }
            .map do |title, texts|
              {
                title: title,
                text: texts.join("\n")
              }
            end

        attachments = [{
          image_url: image_urls.drop(1).first, # drop the image title
          title: query,
          text: "I found you this:",
        }].concat(data_attachments)

        web_client.chat_postMessage channel: data.channel, attachments: attachments
      rescue
        message channel: data.channel, text: "Sorry, I could not complete your query"
      end
    end

    def say_current_temp(data)
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
