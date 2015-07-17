require "freud/version"
require "freud/logging"
require "freud/config"
require "freud/launcher"

module Freud
    class Runner
        include Logging

        def self.run(args = ARGV)
            begin
                new.run(args)
            rescue RunnerExit => exception
                exit(exception.value)
            end
        end

        def run(args)
            command = extract_command(args)
            case(command)
            when "version" then run_version
            when "generate", "g" then run_generate(args)
            when "@check" then run_check(args)
            when "@wait-up" then run_wait_up(args)
            when "@wait-down" then run_wait_down(args)
            when "@signal-term" then run_signal(args, "TERM")
            when "@signal-kill" then run_signal(args, "KILL")
            when "@signal-hup" then run_signal(args, "HUP")
            when "@dump" then run_dump(args)
            else Launcher.new(fetch_config(args).to_hash).run(command, args)
            end
        end

        private

        def fetch_config(args)
            file = extract_file(args)
            stage = extract_stage(args)
            Config.new.load(file, stage)
        end

        def run_version
            logger.info Freud::VERSION
            exit(0)
        end

        def run_generate(args)
            logger.fatal("Usage: freud new [file]") unless args.first
            path = args.first.sub(/(\.json)?$/, ".json")
            name = File.basename(path).sub(/(\.json)?$/, "")
            logger.fatal("File exists: #{path}") if File.exists?(path)
            scaffold = <<-END
                { 
                    "name": "#{name}",
                    "root": "#{File.expand_path(Dir.pwd)}",
                    "background": false,
                    "create_pidfile": false,
                    "reset_env": false,
                    "pidfile": "tmp/#{name}.pid",
                    "logfile": "log/#{name}.log",
                    "vars": {},
                    "env": {},
                    "stages": {
                        "development": {},
                        "production": {}
                    },
                    "commands": {
                        "start": "/bin/false",
                        "stop": "%freud @signal-term; %freud @wait-down",
                        "restart": "%freud stop && %freud start",
                        "reload": "%freud @signal-hup; %freud @wait-up",
                        "kill": "%freud @signal-kill; %freud @wait-down",
                        "status": "%freud @check"
                    }
                }
            END
            lines = scaffold.lines.map { |l| l.rstrip.sub(/^\s{16}/, "") }
            File.open(path, "w") { |f| f.write(lines.join("\n")) }
            exit(0)
        end

        def run_check(args)
            config = fetch_config(args)
            print_status(config)
        end

        def print_status(config)
            pidfile = config.fetch("pidfile")
            name = config.fetch("name")
            if pidfile.running?
                pid = pidfile.read
                logger.info("#{name} up with PID #{pid}.")
            else
                logger.info("#{name} down.")
            end
            exit(0)
        end

        def run_wait_down(args)
            timeout = (extract_option(args, "-t", "--timeout") || 30).to_i
            config = fetch_config(args)
            pidfile = config.fetch("pidfile")
            name = config.fetch("name")
            started_at = Time.now.to_i
            logger.info("Waiting #{timeout} seconds for #{name} to stop.") \
                if pidfile.running?
            while(pidfile.running?)
                sleep(0.25)
                next if ((Time.now.to_i - started_at) < timeout)
                logger.info("#{name} not down within #{timeout} seconds.")
                exit(1)
            end
            print_status(config)
        end

        def run_wait_up(args)
            timeout = (extract_option(args, "-t", "--timeout") || 30).to_i
            config = fetch_config(args)
            pidfile = config.fetch("pidfile")
            name = config.fetch("name")
            started_at = Time.now.to_i
            while(not pidfile.running?)
                sleep(0.25)
                next if ((Time.now.to_i - started_at) < timeout)
                logger.info("#{name} not up within #{timeout} seconds.")
                exit(1)
            end
            print_status(config)
        end

        def run_signal(args, signal)
            config = fetch_config(args)
            pidfile = config.fetch("pidfile")
            exit(1) unless pidfile.running?
            pidfile.kill(signal)
            exit(0)
        end

        def run_dump(args)
            fetch_config(args).dump
            exit(0)
        end

        def extract_flag(args, *flags)
            flags.inject(false) { |out, flag| args.delete(flag) ? true : out }
        end

        def extract_option(args, *options)
            output_args, index, value = [], 0, nil
            while(index < args.length)
                head = args[index]
                tail = args[index + 1]
                if options.include?(head)
                    index += 2
                    value = tail
                else
                    index += 1
                    output_args.push(head)
                end
            end
            args.replace(output_args)
            value
        end

        def extract_command(args)
            return(args.shift) unless args.empty?
            usage
        end

        def extract_file(args)
            service_path = ENV["FREUD_SERVICE_PATH"] || "services"
            path = args.shift
            filename = first_file_in(path, "#{service_path}/#{path}.json",
                ENV["FREUD_CONFIG"])
            usage unless filename
            logger.fatal("Can't open: #{filename}") \
                unless (File.file?(filename) and File.readable?(filename))
            File.open(filename, "r")
        end

        def extract_stage(args)
            args.shift || ENV["FREUD_STAGE"] || "development"
        end

        def first_file_in(*paths)
            paths.each do |path|
                next if path.nil?
                return(path) if File.exists?(path)
            end
            nil
        end

        def usage
            logger.fatal("Usage: freud [command] [file] <stage>")
        end
    end
end
