require "spec_helper"
require "freud/pidfile"

RSpec.describe Freud::Pidfile do
    PIDFILE = "tmp/freud.pid"

    let(:pidfile) { Freud::Pidfile.new(PIDFILE) }

    after(:each) { FileUtils.rm(PIDFILE) if File.exists?(PIDFILE) }

    it "#write" do
        pidfile.write(Process.pid)
        expect(File.exists?(PIDFILE)).to be(true)
    end

    it "#read" do
        expect(pidfile.read).to be_nil
        pidfile.write(Process.pid)
        expect(pidfile.read).to eq(Process.pid)
    end

    it "#running? true" do
        pidfile.write(Process.pid)
        expect(pidfile.running?).to be(true)
    end

    # NOTE: This will (obviously) fail if a process with that pid exists,
    # but it's the maximum pid on a Linux system, and likely to be not used.
    it "#running? false" do
        pidfile.write(32768)
        expect(pidfile.running?).to be(false)
    end

    it "#to_s returns path" do
        expect(pidfile.to_s).to eq(PIDFILE)
    end

    it "== path" do
        expect(pidfile).to eq(PIDFILE)
    end
end
