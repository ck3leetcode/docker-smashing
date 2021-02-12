require 'rest-client'

require 'logger'
require 'json'
require 'securerandom'
require 'date'
require 'concurrent'

module Finnhub
  class Client
    END_POINT = "https://finnhub.io/api/v1"
    API_TOKEN = ENV["FINNHUB_TOKEN"] || "brn42q7rh5r8ci1414tg"

    attr_accessor :logger

    def initialize
      @logger = Logger.new($stdout)
    end

    def quote(symbol)
      path = "/quote"
      param_values = { "symbol" => symbol }

      entity = self.get(path, param_values) do |attrs|
        {
          :type => "QUOTE",
          :symbol => symbol,
          :open => attrs["o"],
          :high => attrs["h"],
          :low => attrs["l"],
          :current => attrs["c"],
          :timestamp => attrs["t"],
          :error => attrs["err"],
          :previous_close => attrs['pc'],
        }
      end

      entity
    end

    def historic_quotes(symbol, start_date, end_date)
      path = "/stock/candle"
      param_values = { 
        "symbol" => symbol,
        "resolution" => "D",
        "from" => start_date.to_time.to_i,
        "to" => end_date.to_time.to_i,
      }

      entity = self.get(path, param_values) do |attrs|
        return nil unless attrs["s"] == "ok"

        opens = attrs["o"]
        highs = attrs["h"]
        lows = attrs["l"]
        closes = attrs["c"]
        timestamps = attrs["t"]

        # exclusive
        results = (0...opens.count).map do |i|
          {
            :type => "QUOTE",
            :symbol => symbol,
            :open => opens[i],
            :high => highs[i],
            :low => lows[i],
            :current => closes[i],
            :timestamp => timestamps[i],
            :error => nil,
            :previous_close => (closes[i - 1] if i > 0),
          }
        end

        results
      end
    end


    def price_target(symbol)
      path = "/stock/price-target"
      param_values = { "symbol" => symbol } 

      entity = self.get(path, param_values) do |attrs|
        {
          :type => "PRICE_TARGET",
          :symbol => symbol,
          :high => attrs["targetHigh"],
          :low => attrs["targetLow"],
          :mean => attrs["targetMean"],
          :median => attrs["targetMedian"],
          :last_updated => attrs["lastUpdated"],
        }
      end

      entity
    end

    def recommendation(symbol)
      path = "/stock/recommendation"
      param_values = { "symbol" => symbol }
      
      entities = self.get(path, param_values) do |attr_list|
        attr_list.map do |attrs|
          {
            :type => "RECOMMENDATION",
            :symbol => symbol,
            :buy => attrs["buy"],
            :hold => attrs["hold"],
            :sell => attrs["sell"],
            :strong_buy => attrs["strongBuy"],
            :strong_sell => attrs["strongSell"],
            :period => attrs["period"],
          }
        end
      end

      entities
    end

    def calendar_earnings(options = { :from => Time.now, :to => Time.now })
      # sample: /calendar/earnings?from=2010-01-01&to=2020-03-15&symbol=AAPL
      end_point = "/calendar/earnings"
      params_values = {
        :from => options[:from].strftime("%Y-%m-%d"),
        :to => options[:to].strftime("%Y-%m-%d")
      }
  
      entities = self.get(path, param_values) do |attrs|
        attr_list = attrs["earningsCalendar"]
        attr_list.map do |attrs|
          {
            :symbol => symbol,
            :eps_actual => attrs["epsActual"],
            :eps_estimate => attrs["epsEstimate"],
            :hour => attrs["hour"],
            :quarter => attrs["quarter"],
            :revenue_actual => attrs["revenueActual"],
            :revenue_estimate => attrs["revenueEstimate"],
            :year => attrs["year"],
            :date => attrs["date"],
            :last_updated => Time.now
          }
        end
      end

      entity
    end

    # Helpers

    def get(path, param_values = {})
      url = "#{Finnhub::Client::END_POINT}#{path}"
      token = Finnhub::Client::API_TOKEN

      param_values_with_token = param_values.merge("token" => token)

      logger.info("#{url} with params: #{param_values}")
      response = RestClient.get(url, { params: param_values_with_token } )  

      attributes = JSON.parse(response.body) if response.code == 200
      if attributes.nil?
        logger.error("failed to fetch for #{symbol}. #{response.body}")
        return nil
      end
            
      entity = yield attributes
      entity
    end
  end
end