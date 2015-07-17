require "spec_helper"
require "freud/config"

RSpec.describe Freud::Config do
    let(:config) { Freud::Config.new }

    describe "#snakify_string" do
        def call(input)
            config.snakify_string(input)
        end

        it { expect(call("")).to eq("") }

        it { expect(call("hello")).to eq("hello") }

        it { expect(call("helloWorld")).to eq("hello_world") }

        it { expect(call("HelloWorld")).to eq("hello_world") }

        it { expect(call("Helloworld")).to eq("helloworld") }

        it { expect(call("ThinkABC")).to eq("think_abc") }
    end

    describe "#expand_path" do
        def call(path, relative_to)
            config.expand_path(path, relative_to)
        end

        it { expect(call(".", "/tmp")).to eq("/tmp") }

        it { expect(call("../root", "/tmp")).to eq("/root") }

        it { expect(call("/root", "/tmp")).to eq("/root") }

        it { expect(call("foo", "/tmp")).to eq("/tmp/foo") }
    end

    it "#deep_merge" do
        left = { a: { b: { c: 42 } } }
        right = { a: { b: { d: 72 } } }
        output = { a: { b: { c: 42, d: 72 } } }
        expect(config.deep_merge(left, right)).to eq(output)
    end

    it "#snakify_keys" do
        input = { "aKey" => "a" }
        expect(config.snakify_keys(input)).to eq("a_key" => "a")
    end

    it "#snakify_keys not recursive" do
        input = { "aKey" => { "bKey" => "b" } }
        expect(config.snakify_keys(input)).to eq("a_key" => { "bKey" => "b" })
    end

    describe "#load" do
        def mock_file(name, content = nil)
            default = { stages: { back: {} } }
            content ||= block_given? ? yield : default
            content = JSON.dump(content) if content.is_a?(Hash)
            double(read: content, path: name, close: true)
        end

        def call(file, stage = "development")
            Freud::Config.new.load(file, stage)
        end

        let(:root) { File.expand_path("#{File.dirname(__FILE__)}/..") }

        it "name from file with extension" do
            config = call(mock_file("monkey.json"))
            expect(config.fetch("name")).to eq("monkey")
        end

        it "name from file with extension" do
            config = call(mock_file("monkey"))
            expect(config.fetch("name")).to eq("monkey")
        end

        it "pidfile tmp/%name" do
            config = call(mock_file("monkey"))
            expect(config.fetch("pidfile")).to eq("#{root}/tmp/monkey.pid")
        end

        it "pidfile %HOME/tmp/%name" do
            home = ENV["HOME"]
            content = { pidfile: "%HOME/tmp/%name.pid" }
            config = call(mock_file("monkey", content))
            expect(config.fetch("pidfile")).to eq("#{home}/tmp/monkey.pid")
        end

        it "logfile" do
            content = { logfile: "log/%name.log" }
            config = call(mock_file("monkey", content))
            expect(config.fetch("logfile")).to eq("#{root}/log/monkey.log")
        end

        it "env FREUD_STAGE" do
            config = call(mock_file("monkey"), "back")
            env = config.to_hash.fetch("env")
            expect(env["FREUD_STAGE"]).to eq("back")
        end

        it "background" do
            config = call(mock_file("monkey", background: true))
            expect(config.fetch("background")).to be(true)
        end

        it "reset_env" do
            config = call(mock_file("monkey", reset_env: true))
            expect(config.fetch("reset_env")).to be(true)
        end

        it "create_pidfile" do
            config = call(mock_file("monkey", create_pidfile: true))
            expect(config.fetch("create_pidfile")).to be(true)
        end

        it "javascript comments" do
            content = mock_file("monkey", <<-END)
                {
                    // Comment one.
                    "reset_env": true,
                    /* Comment two */
                    "name": "quux"
                }
            END
            config = call(content)
            expect(config.fetch("reset_env")).to be(true)
            expect(config.fetch("name")).to eq("quux")
        end

        it "interpolates fully-merged" do
            vars = { vars: { "RUNAS_USER" => "bob" } }
            content = mock_file("monkey", sudo_user: "%RUNAS_USER",
                stages: { development: vars })
            config = call(content)
            expect(config.fetch("sudo_user")).to eq("bob")
        end
    end
end
