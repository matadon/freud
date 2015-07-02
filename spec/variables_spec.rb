require "spec_helper"
require "freud/variables"

RSpec.describe Freud::Variables do
    let(:vars) { Freud::Variables.new }

    it "#merge" do
        vars.merge(answer: 42)
        expect(vars.fetch(:answer)).to eq(42)
    end

    it "#fetch unknown" do
        expect { vars.fetch(:answer) }.to raise_error(KeyError)
    end

    it "#fetch default" do
        expect(vars.fetch(:answer, 42)).to eq(42)
    end

    describe "#apply" do
        before(:each) { vars.merge(answer: 42) }

        it { expect(vars.apply("answer")).to eq("answer") }

        it { expect(vars.apply("%answer")).to eq("42") }

        it { expect(vars.apply("%{answer}")).to eq("42") }

        it { expect(vars.apply("\\%answer")).to eq("%answer") }

        it { expect(vars.apply("\\%{answer}")).to eq("%{answer}") }

        it { expect(vars.apply("\\%{nope|66}")).to eq("%{nope|66}") }

        it { expect(vars.apply("%{nope|66}")).to eq("66") }

        it { expect(vars.apply("%{answer|66}")).to eq("42") }

        it { expect(vars.apply("%answer|66")).to eq("42|66") }

        it { expect { vars.apply("%ANSWER") }.to raise_error(KeyError) }

        it "nested" do
            vars.merge(outer: "a %inner", inner: "b")
            expect(vars.apply("%outer")).to eq("a b")
        end

        it "nested default" do
            vars.merge(outer: "a %{nope|%inner}", inner: "b")
            expect(vars.apply("%outer")).to eq("a b")
        end

        it "nested loop" do
            vars.merge(outer: "a %inner", inner: "b %outer")
            expect { vars.apply("%outer") }.to raise_error(RuntimeError)
        end
    end

    describe "#test" do
        it { expect(vars.test("%answer")).to be(true) }

        it { expect(vars.test("%{answer}")).to be(true) }

        it { expect(vars.test("%{answer|66}")).to be(true) }

        it { expect(vars.test("answer")).to be(false) }

        it { expect(vars.test("\\%answer")).to be(false) }

        it { expect(vars.test("\\%{answer}")).to be(false) }

        it { expect(vars.test("\\%{answer|66}")).to be(false) }
    end
end
