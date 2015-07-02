require "spec_helper"
require "fileutils"
require "stringio"
require "freud/logging"
require "freud/launcher"
require "freud/pidfile"

RSpec.describe Freud::Launcher do
    let(:log) { StringIO.new }

    before(:each) { Freud::Logging.log_to(log) }

    it "#new" do
        fields = %w(name root pidfile logfile background create_pidfile
            reset_shell_env shell_env commands)
        command = Freud::Launcher.new(Hash[fields.map { |k| [ k, 42 ] }])
        fields.each { |f| expect(command.send(f)).to eq(42) }
    end

    describe "#run" do
        let(:process) { double }

        let(:pidfile) { double(Freud::Pidfile) }

        after(:each) { FileUtils.rm_f("tmp/foo.json") }

        def try(config, runnable, *args, &block)
            command = Freud::Launcher.new(config)
            trial = lambda { command.run(runnable, args) }
            return(trial.call) unless block_given?
            expect(trial).to raise_error(Freud::RunnerExit, &block)
        end

        describe "execute" do
            it "bad external command" do
                allow(pidfile).to receive(:read).and_return(35767)
                config = { "process" => process, "pidfile" => pidfile,
                    "shell_env" => {}, "commands" => {} }
                try(config, "notacommand") { |e| expect(e.value).to eq(1) }
            end

            it "test: /bin/true" do
                allow(pidfile).to receive(:read).and_return(35767)
                config = { "process" => process, "pidfile" => pidfile,
                    "shell_env" => {}, "commands" => { "test" => "/bin/true" } }
                expect(process).to receive(:exec).with({}, "/bin/true",
                    { unsetenv_others: false, chdir: nil, close_others: true,
                    in: "/dev/null", out: :err })
                try(config, "test")
            end
        end

        describe "daemonize" do
            it "bad external command" do
                allow(pidfile).to receive(:read).and_return(35767)
                config = { "process" => process, "pidfile" => pidfile,
                    "shell_env" => {}, "commands" => {} }
                try(config, "start") { |e| expect(e.value).to eq(1) }
            end

            it "background: false" do
                allow(pidfile).to receive(:read).and_return(nil)
                allow(pidfile).to receive(:running?).and_return(false)
                allow(process).to receive(:pid).and_return(35767)
                config = { "process" => process, "pidfile" => pidfile,
                    "shell_env" => {}, "background" => false,
                    "commands" => { "start" => "/bin/true" } }
                expect(process).to receive(:exec).with({}, "/bin/true",
                    { unsetenv_others: false, chdir: nil, close_others: true,
                    in: "/dev/null", out: :err })
                try(config, "start")
            end

            it "background: true" do
                allow(pidfile).to receive(:read).and_return(nil)
                allow(pidfile).to receive(:running?).and_return(false)
                config = { "process" => process, "pidfile" => pidfile,
                    "shell_env" => {}, "background" => true,
                    "commands" => { "start" => "/bin/true" } }
                expect(process).to receive(:spawn).with({}, "/bin/true",
                    { unsetenv_others: false, chdir: nil, close_others: true,
                    in: "/dev/null", out: :err, pgroup: true })
                try(config, "start")
            end

            it "reset_shell_env" do
                allow(pidfile).to receive(:read).and_return(nil)
                allow(pidfile).to receive(:running?).and_return(false)
                allow(process).to receive(:pid).and_return(35767)
                config = { "process" => process, "pidfile" => pidfile,
                    "shell_env" => {}, "reset_shell_env" => true,
                    "commands" => { "start" => "/bin/true" } }
                expect(process).to receive(:exec).with({}, "/bin/true",
                    { unsetenv_others: true, chdir: nil, close_others: true,
                    in: "/dev/null", out: :err })
                try(config, "start")
            end

            it "create_pidfile" do
                allow(pidfile).to receive(:read).and_return(nil)
                allow(pidfile).to receive(:running?).and_return(false)
                allow(pidfile).to receive(:write).with(35767)
                allow(process).to receive(:pid).and_return(35767)
                config = { "process" => process, "pidfile" => pidfile,
                    "shell_env" => {}, "create_pidfile" => true,
                    "commands" => { "start" => "/bin/true" } }
                expect(process).to receive(:exec).with({}, "/bin/true",
                    { unsetenv_others: false, chdir: nil, close_others: true,
                    in: "/dev/null", out: :err })
                try(config, "start")
            end
        end
    end
end
