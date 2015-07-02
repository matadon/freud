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

        after(:each) { ENV.delete("FREUD_CONFIG") }

        it "checkpid (up)" do
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(Process.pid)
            args = [ "checkpid", "spec/fixtures/true" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
        end

        it "checkpid via FREUD_CONFIG" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(Process.pid)
            args = [ "checkpid" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
        end

        it "checkpid (down)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            args = [ "checkpid", "spec/fixtures/true" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(1) }
        end

        it "waitpid (up)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(Process.pid)
            args = [ "waitpid", "-t", "1" ]
            started_at = Time.now.to_i
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(1) }
            expect(Time.now.to_i - started_at).to be < 2
        end

        it "waitpid (down)" do
            ENV["FREUD_CONFIG"] = "spec/fixtures/true"
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            args = [ "waitpid" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
        end

        it "generate" do
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            args = [ "g", "tmp/generated" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            expect(File.exists?("#{root}/tmp/generated.json")).to be(true)
        end

        it "usage" do
            Freud::Pidfile.new("#{root}/tmp/true.pid").write(unused_pid)
            try(lambda { runner.run([]) }) do |result|
                expect(result.value).to eq(1)
                expect(result.message).to match(/usage/i)
            end
        end

        it "help" do
            args = [ "help", "spec/fixtures/true" ]
            try(lambda { runner.run(args) }) { |r| expect(r.value).to eq(0) }
            log.rewind
            expect(log.read).to match(/quux/)
        end
    end
end
