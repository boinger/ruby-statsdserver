require "logger"

class StatsdServer::Output
  class Amqp
    attr_accessor :logger

    public
    def initialize(opts = {})
      begin
        require "bunny"
      rescue LoadError => e
        raise unless e.message =~ /bunny/
        new_e = e.exception("Please install the bunny gem for AMQP output.")
        new_e.set_backtrace(e.backtrace)
        raise new_e
      end

      if opts["exchange_type"].nil?
        raise ArgumentError, "missing host in [output:amqp] config section"
      end

      if opts["exchange_name"].nil?
        raise ArgumentError, "missing port in [output:amqp] config section"
      end

      @opts = opts
      @logger = Logger.new(STDOUT)
    end

    public
    def send(str)
      if @bunny.nil?
        @bunny, @exchange = connect
      end

      begin
        @exchange.publish(str)
      rescue => e
        @bunny.close_connection rescue nil
        @bunny = nil
        raise
      end
    end

    private
    def connect
      opts_sym = Hash[@opts.map { |k,v| [k.to_sym,v] }]
      bunny = Bunny.new(opts_sym)
      bunny.start

      exchange = bunny.exchange(
        @opts["exchange_name"],
        :type => @opts["exchange_type"].to_sym,
        :durable => @opts["exchange_durable"] == "true" ? true : false,
        :auto_delete => @opts["exchange_auto_delete"] == "true" ? true : false
      )

      return bunny, exchange
    end
  end # class Amqp
end # class StatsdServer::Output
