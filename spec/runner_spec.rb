require "spec_helper"
require "freud/runner"
require "set"

RSpec.describe Freud::Runner do
    def unused_pid
        used = Set.new(`ps -A | awk '{print $1}'`.split(/\n/))
        output = 35767.step(1, -1).find { |pid| not used.include?(pid.to_s) }
        raise("Can't find an unused pid.") unless output
        output
    end

    let(:root) { File.expand_path("#{File.dirname(__FILE__)}/..") }

    let(:runner) { Freud::Runner.new }

    let(:process) { double }

    let(:pidfile) { double(Freud::Pidfile) }

    let(:log) { StringIO.new }

    before(:each) { Freud::Logging.log_to(log) }
    
    after(:each) do
        FileUtils.rm_f("tmp/generated.json")
        FileUtils.rm_f("tmp/true.pid")
    end

    it ".run" do
        expect { Freud::Runner.run([]) }.to raise_error(SystemExit)
    end

    describe "#run" do
        def try(runnable, &block)
            expect(runnable).to raise_error(Freud::RunnerExit, &block)
        end

        after(:each) do
            ENV.delete("FREUD_CONFIG")
            ENV.delete("FREUD_STAGE")
            ENV.delete("FREUD_SERVICE_PATH")
        end

        it "@check (up)" do
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(Process.pid)
            args = [ "@check", "spec/fixtures/true.json" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
        end

        it "@check via FREUD_CONFIG" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true.json"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(Process.pid)
            args = [ "@check" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            log.rewind
            expect(log.read).to match(/\bup\b/)
        end

        it "@check (down)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true.json"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            args = [ "@check", "spec/fixtures/true.json" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            log.rewind
            expect(log.read).to match(/\bdown\b/)
        end

        it "@wait-up (up)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true.json"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(Process.pid)
            args = [ "@wait-up", "-t", "1" ]
            started_at = Time.now.to_i
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            expect(Time.now.to_i - started_at).to be < 2
        end

        it "@wait-up (down)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true.json"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            args = [ "@wait-up", "-t", "1" ]
            started_at = Time.now.to_i
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(1) }
            expect(Time.now.to_i - started_at).to be < 2
        end

        it "@wait-down (down)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true.json"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            args = [ "@wait-down", "-t", "1" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
        end

        it "@wait-down (up)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true.json"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(Process.pid)
            args = [ "@wait-down", "-t", "1" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(1) }
        end

        it "generate" do
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            args = [ "g", "tmp/generated.json" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            generated = "#{root}/tmp/generated.json"
            expect(File.exists?(generated)).to be(true)
            expect { JSON.parse(File.read(generated)) }.to_not raise_error
        end

        it "usage" do
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            try(lambda { runner.run([]) }) do |result|
                expect(result.value).to eq(1)
                expect(result.message).to match(/usage/i)
            end
        end

        it "help" do
            args = [ "help", "spec/fixtures/true.json" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            log.rewind
            expect(log.read).to match(/quux/)
        end

        it "FREUD_SERVICE_PATH" do
            ENV["FREUD_SERVICE_PATH"] = "spec/fixtures"
            args = [ "help", "true" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            log.rewind
            expect(log.read).to match(/quux/)
        end
    end
end
