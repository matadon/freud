require "agrippa/mutable"
require "freud/logging"

module Freud
    class Launcher
        include Logging

        include Agrippa::Mutable

        state_reader %w(name root pidfile logfile background create_pidfile
            reset_shell_env shell_env commands sudo_user args)

        state_accessor :process

        def default_state
            { process: Process }
        end

        def run(command, args = [])
            @args = args
            case(command)
                when "help" then show_help
                when "start" then daemonize(fetch_executable(command))
                else execute(fetch_executable(command))
            end
        end

        private

        def fetch_executable(command)
            apply_sudo do
                commands.fetch(command) do
                    show_help(false)
                    logger.fatal("Unknown command: #{command}") 
                end
            end
        end

        def apply_sudo
            command = yield
            return(command) unless sudo_user
            sudo = "sudo --preserve-env --non-interactive --user #{sudo_user}"
            bash = sprintf("bash -c \"%s\"", command.gsub(/"/, '\\"'))
            "#{sudo} -- #{bash}"
        end

        def show_help(terminate = true)
            logger.info("Valid commands: #{commands.keys.join(", ")}")
            exit(0) if terminate
            self
        end

        def execute(command, options = nil)
            log_runtime_environment(command)
            $PROGRAM_NAME = command
            process.exec(shell_env, command, options || spawn_options)
            self
        end

        def daemonize(command)
            return(self) if running?
            options = spawn_options
            options[:err] = [ logfile, "a" ] if logfile
            create_logfile
            if background
                options.merge!(pgroup: true)
                log_runtime_environment(command, options)
                pid = process.spawn(shell_env, command, options)
                maybe_create_pidfile(pid)
            else
                $PROGRAM_NAME = command
                maybe_create_pidfile(process.pid)
                execute(command, options)
            end
        end

        def log_runtime_environment(command, options = nil)
            options ||= spawn_options
            logger.debug("running #{command}")
            logger.debug("env #{ENV.inspect}")
            logger.debug("shell_env #{shell_env.inspect}")
            logger.debug("spawn_options #{options.inspect}")
            self
        end

        def create_logfile
            return unless logfile
            begin
                file = File.open(logfile, "a")
                file.close
            rescue
                logger.fatal("Unable to open logfile: #{logfile}")
            end
            self
        end

        def spawn_options
            output = {}
            output[:unsetenv_others] = (reset_shell_env == true)
            output[:chdir] = root
            output[:close_others] = true
            output[:in] = "/dev/null"
            output[:out] = :err
            output
        end

        def maybe_create_pidfile(pid)
            return(self) unless (create_pidfile == true)
            pidfile.write(pid)
            self
        end

        # FIXME  Kill stale pidfile?
        def running?
            pidfile.running?
        end
    end
end
