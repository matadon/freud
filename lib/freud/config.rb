require "freud/variables"
require "freud/pidfile"
require "agrippa/delegation"
require "json"

module Freud
    class Config
        UNDEFINED = Object.new

        include Agrippa::Delegation

        attr_reader :config, :vars

        delegate :merge, :store, :fetch, :apply, to: :vars, suffix: true

        def initialize
            @config = {}
            @vars = Variables.new
        end

        def load(file, environment)
            json = load_json(file)
            merge(defaults(file))
            merge(globals(json))
            merge(environmental(environment))
            merge(overrides(environment))
            initialize_vars(file)
            interpolate_shell_env
            interpolate_commands
            config.delete("environments")
            config.delete("vars")
            self
        end

        def dump(root = nil, level = 0)
            root ||= @config
            indent = "    " * level
            root.each_pair do |key, value|
                if value.respond_to?(:each_pair)
                    puts "#{indent}#{key}:"
                    dump(value, level + 1)
                else
                    puts "#{indent}#{key}: #{value}"
                end
            end
            self
        end

        def load_json(file)
            output = JSON.parse(file.read)
            file.close
            output
        end

        def to_hash
            config
        end
    
        def initialize_vars(file)
            merge_vars(ENV)
            merge_vars(name: default_name(file))
            merge_vars(self: path_to_running_script)
            merge_vars(fetch(:vars))
            default_root = File.dirname(file.path)
            root_path = expand_path(fetch(:root), default_root)
            store_vars(:root, root_path)
            store(:root, root_path)
            interpolate(:pidfile)
            pidfile_path = expand_path(fetch(:pidfile), root_path)
            store(:pidfile, Pidfile.new(pidfile_path))
            interpolate(:logfile)
            store(:logfile, expand_path(fetch(:logfile), root_path))
            store_vars(:pid, read_pidfile)
        end

        def default_name(file)
            File.basename(file.path).gsub(/\.\w*$/, '')
        end

        def path_to_running_script
            File.expand_path($PROGRAM_NAME)
        end

        def merge(hash)
            deep_merge(@config, validate(hash))
        end

        def store(key, value)
            @config.store(key.to_s, value)
            self
        end

        def fetch(key, default = UNDEFINED)
            return(@config.fetch(key.to_s)) if (default == UNDEFINED)
            @config.fetch(key.to_s, default)
        end

        def validate(hash)
            strings = %w(root pidfile logfile sudo_user)
            strings.each { |key| validate_string(key, hash[key]) }
            booleans = %w(background create_pidfile reset_shell_env)
            booleans.each { |key| validate_boolean(key, hash[key]) }
            hashes = %w(vars shell_env commands)
            hashes.each { |key| validate_hash(key, hash[key]) }
            hash
        end

        def validate_string(key, value)
            return(true) if (value.nil? or value.is_a?(String))
            raise("#{key} must be a string.")
        end

        def validate_boolean(key, value)
            return(true) if value.nil?
            return(true) if (value == true or value == false)
            raise("#{key} must be a boolean.")
        end

        def validate_hash(key, value)
            return(true) if value.nil?
            raise("#{key} must be a hash.") unless value.is_a?(Hash)
            value.each_pair { |k, v| validate_string("#{key}.#{k}", v) }
            true
        end

        def expand_path(path, relative_to)
            return(File.expand_path(path)) if is_absolute_path(path)
            File.expand_path(File.join(relative_to, path))
        end

        def is_absolute_path(path)
            (path =~ /^\//) ? true : false
        end

        def read_pidfile
            fetch(:pidfile).read
        end

        def interpolate_shell_env
            shell_env = fetch(:shell_env)
            shell_env.each_pair { |k, v| shell_env[k] = apply_vars(v) }
            self
        end

        def interpolate_commands
            commands = fetch(:commands)
            commands.each_pair { |k, v| commands[k] = apply_vars(v) }
            self
        end

        def snakify_keys(hash)
            output = {}
            hash.each_pair { |k, v| output.store(snakify_string(k), v) }
            output
        end

        def snakify_string(input)
            input.gsub(/(.)([A-Z][a-z]+)/, '\1_\2')
                .gsub(/(.)([0-9]+)/, '\1_\2')
                .gsub(/([a-z0-9])([A-Z])/, '\1_\2')
                .downcase
        end

        def defaults(file)
            deep_stringify_keys(
                name: File.basename(file.path).gsub(/\..*$/, ''),
                root: File.dirname(file.path),
                background: false,
                create_pidfile: false,
                reset_shell_env: false,
                pidfile: "tmp/%name.pid",
                vars: {},
                shell_env: { FREUD_CONFIG: file.path },
                environments: { development: {}, production: {} },
                commands: {
                    stop: "%self checkpid quiet && kill -TERM %pid",
                    restart: "%self stop && %self start",
                    reload: "%self checkpid quiet && kill -HUP %pid",
                    kill: "%self checkpid quiet && kill -KILL %pid",
                    status: "%self checkpid" })
        end

        def globals(json)
            snakify_keys(json)
        end

        def environmental(name)
            environments = snakify_keys(config.fetch("environments"))
            environments.fetch(name) { raise("Unknown environment: #{name}")}
        end

        def overrides(environment)
            deep_stringify_keys(
                vars: { environment: environment },
                shell_env: { FREUD_ENV: "%environment" })
        end

        def interpolate(key)
            value = apply_vars(fetch(key, ""))
            store_vars(key, value)
            store(key, value)
        end

        def deep_merge(under, over)
            over.each_pair do |key, over_value|
                under_value = under[key]
                if(under_value.is_a?(Hash) and over_value.is_a?(Hash))
                    under.store(key, deep_merge(under_value, over_value))
                else
                    under.store(key, over_value)
                end
            end
            under
        end

        def deep_stringify_keys(hash)
            output = {}
            hash.each_pair do |key, value|
                next(output.store(key.to_s, value)) unless value.is_a?(Hash)
                output.store(key.to_s, deep_stringify_keys(value))
            end
            output
        end
    end
end
