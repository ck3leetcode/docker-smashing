require 'rest-client'

require_relative './finnhub_client'

require 'logger'
require 'json'
require 'securerandom'
require 'date'
require 'concurrent'

QUOTE_LIST = [
  "AAPL",
  "TSLA",
  "MSFT",
  "Z",
  "TSM",
  "TWTR",
  "FB",
  "ARKW",
  "ARKG"
]


SCHEDULER.every '10s' do
  quotes = StonkHelper.get_batch_requests(QUOTE_LIST.sort)
  events = quotes.map do |quote| 
    {label: quote[:symbol], value: quote[:current]}
  end

  send_event('stonks', { items: events})
end


module StonkHelper
  class << self
    attr_accessor :logger
  end
  self.logger = Logger.new($stdout)

  def self.get_batch_requests(symbols)
    logger.info("get_batch_requests. input size: #{symbols.count}")
    
    pool = Concurrent::FixedThreadPool.new(1)
    promises = symbols.map do |symbol|
      Concurrent::Promise.execute( {executor: pool}) do
        client = Finnhub::Client.new
        results = [ client.quote(symbol) ]
        results
        
      end.rescue do |exception|
        results = [ 
          {
            :symbol => symbol,
            :type => type,
            :error => exception.to_json
          } 
        ]

        logger.error("get_batch_requests error: #{results}")
        results
      end
    end

    results = promises.map(&:value)
    results = results.flatten.compact
    results = results.select { |result| result[:error].nil? }
    logger.info("get_batch_requests: succeed count = #{results.count}")
    results
  end
end

