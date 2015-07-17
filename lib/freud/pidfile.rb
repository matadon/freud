require "freud/logging"

module Freud
    class Pidfile
        include Logging

        def initialize(path)
            @path = path
        end

        def write(pid)
            File.open(@path, "w") { |f| f.write(pid.to_s) }
            self
        end

        def read
            return unless @path
            return unless (File.exists?(@path) and File.readable?(@path))
            output = File.read(@path)
            output ? output.to_i : nil
        end

        def to_s
            @path
        end

        def ==(other)
            File.expand_path(to_s) == File.expand_path(other.to_s)
        end

        def kill(signal)
            pid = read
            return(self) unless pid
            Process.kill(signal, pid)
            self
        end

        def running?
            begin
                kill(0)
                true
            rescue Errno::ESRCH
                false
            rescue Errno::EPERM
                true
            end
        end
    end
end
