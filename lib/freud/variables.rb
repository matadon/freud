require "agrippa/mutable_hash"

module Freud
    class Variables
        VARIABLES = /(?<!\\)%((\w+)|{(\w+)}|{(\w+)\|(.*)})/i

        ESCAPED_SIGILS = /\\%/

        UNDEFINED = Object.new

        include Agrippa::MutableHash

        def initialize(*args)
            super
            @stack = {}
        end

        def each_pair(&block)
            @state.each_pair(&block)
        end

        def test(input)
            (input =~ VARIABLES) ? true : false
        end

        def merge(updates)
            chain(updates)
        end

        def fetch(key, default = UNDEFINED)
            key = key.to_sym
            return(@state.fetch(key, default)) unless (default == UNDEFINED)
            @state.fetch(key) { raise(KeyError, "Unknown variable: #{key}") }
        end

        def apply(input)
            return(nil) if input.nil?
            interpolated = input.gsub(VARIABLES) do 
                key = $~[2] || $~[3] || $~[4] 
                default = $~[5] || UNDEFINED
                push_stack(key, input)
                output = apply(fetch(key, default).to_s)
                pop_stack(key)
                output
            end
            interpolated.gsub(ESCAPED_SIGILS, "%")
        end

        def push_stack(key, input)
            if @stack[key]
                message = "Infinite loop evaluating '%#{key}' in '#{input}'"
                raise(RuntimeError, message)
            else
                @stack[key] = true
                self
            end
        end

        def pop_stack(key)
            @stack.delete(key)
            self
        end
    end
end
