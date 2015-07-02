require "logger"

module Freud
    class RunnerExit < StandardError
        attr_reader :message, :value

        def initialize(message, value = 1)
            @message, @value = message, value
        end
    end

    class FreudLogger < Logger
        def initialize(*args)
            super
            debug_on = ENV.has_key?("DEBUG")
            self.level = debug_on ? Logger::DEBUG : Logger::INFO
            self.formatter = proc { |s, t, p, m| "#{m.strip}\n" }
        end

        def fatal(message)
            super
            raise(RunnerExit.new(message, 1))
        end
    end

    module Logging
        def self.log_to(stream)
            @logger = FreudLogger.new(stream)
            self
        end

        def self.logger
            @logger ||= FreudLogger.new($stderr)
        end

        def logger
            Freud::Logging.logger
        end

        def exit(value = 0)
            raise(RunnerExit.new(nil, value))
        end
    end
end
