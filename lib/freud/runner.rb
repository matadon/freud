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
            when "generate", "g" then run_generate(args)
            when "checkpid" then run_checkpid(args)
            when "waitpid" then run_waitpid(args)
            when "dump-config" then run_dump_config(args)
            else Launcher.new(fetch_config(args).to_hash).run(command, args)
            end
        end

        private

        def fetch_config(args)
            file = extract_file(args)
            environment = extract_environment(args)
            Config.new.load(file, environment)
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
                    "reset_shell_env": false,
                    "pidfile": "tmp/#{name}.pid",
                    "logfile": "log/#{name}.log",
                    "vars": {},
                    "shell_env": {},
                    "environments": {
                        "development": {},
                        "production": {}
                    },
                    "commands": {
                        "start": "/bin/false",
                        "stop": "%self checkpid quiet && kill -TERM %pid && %self waitpid",
                        "restart": "%self stop && %self start",
                        "reload": "%self checkpid quiet && kill -HUP %pid",
                        "kill": "%self checkpid quiet && kill -KILL %pid",
                        "status": "%self checkpid"
                    }
                }
            END
            lines = scaffold.lines.map { |l| l.rstrip.sub(/^\s{16}/, "") }
            File.open(path, "w") { |f| f.write(lines.join("\n")) }
            exit(0)
        end

        def run_checkpid(args)
            quiet = extract_flag(args, "-q", "--quiet")
            config = fetch_config(args)
            pidfile = config.fetch("pidfile")
            name = config.fetch("name")
            if pidfile.running?
                pid = pidfile.read
                logger.info("#{name} up with PID #{pid}.") unless quiet
                exit(0)
            else
                logger.info("#{name} down.") unless quiet
                exit(1)
            end
        end

        def run_waitpid(args)
            timeout = (extract_option(args, "-t", "--timeout") || 5).to_i
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
            logger.info("#{name} down.")
            exit(0)
        end

        def run_dump_config(args)
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
            filename = first_file_in(args.shift, ENV["FREUD_CONFIG"])
            usage unless filename
            logger.fatal("Can't open: #{filename}") \
                unless (File.file?(filename) and File.readable?(filename))
            File.open(filename, "r")
        end

        def extract_environment(args)
            args.shift || ENV["FREUD_ENV"] || "development"
        end

        def first_file_in(*paths)
            paths.each do |path|
                next if path.nil?
                json_path = path.sub(/(\.json)?$/, ".json")
                return(json_path) if File.exists?(json_path)
            end
            nil
        end

        def usage
            logger.fatal("Usage: freud [command] [file] <environment>")
        end
    end
end
