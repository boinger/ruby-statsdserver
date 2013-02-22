require "rubygems"
require "bundler/setup"

require "rspec/autorun"
require "statsdserver"
require "spec_helper"

describe StatsdServer do
  describe "#carbon_update_str" do
    it "should calculate rate for counters" do
      s = StatsdServer.new({:flush_interval => 10}, {}, {})
      s.stats.counters["test.counter"] = 5

      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.test.counter")
      res[1].should eq("0.5")
    end

    it "should send zeros for a known counter with no updates" do
      s = StatsdServer.new({}, {}, {})
      s.stats.counters["test.counter"] = 5

      res = s.carbon_update_str   # "flush" the test.counter rate
      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.test.counter")
      res[1].should eq("0.0")
    end

    it "should not send zeros for a known counter with no updates when preserve_counters is false" do
      s = StatsdServer.new({:preserve_counters => "false"}, {}, {})
      s.stats.counters["test.counter"] = 5

      res = s.carbon_update_str   # "flush" the test.counter rate
      res = s.carbon_update_str.should eq(nil)
    end

    it "should prepend prefix to metrics" do
      s = StatsdServer.new({:prefix => "foostatsd"}, {}, {})
      s.stats.counters["test.counter"] = 5
      res = s.carbon_update_str.split(" ")
      res[0].should eq("foostatsd.test.counter")
    end

    it "should append suffix to metrics" do
      s = StatsdServer.new({:suffix => "foo.bar"}, {}, {})
      s.stats.counters["test.counter"] = 5
      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.test.counter.foo.bar")
    end

    it "should default to timer name before suffix" do
      s = StatsdServer.new({:suffix => "foo.bar"}, {}, {})
      s.stats.timers["test.timer"] = [1, 1, 1]
      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.timers.test.timer.mean.foo.bar")
    end

    it "should allow timer name after suffix" do
      opts = {
          :suffix => "foo.bar",
          :timer_names_before_suffix => "false",
      }
      s = StatsdServer.new(opts, {}, {})
      s.stats.timers["test.timer"] = [1, 1, 1]
      res = s.carbon_update_str.split(" ")
      res[0].should eq("stats.timers.test.timer.foo.bar.mean")
    end

    it "should calculate statistics for timers" do
      s = StatsdServer.new({}, {}, {})
      1.upto(10) { |i| s.stats.timers["test.timer"] << i }
      result = {}
      s.carbon_update_str.split("\n").each do |line|
        metric, value, _unused = line.split(" ")
        result[metric] = value
      end
      result["stats.timers.test.timer.lower"].should eq("1")
      result["stats.timers.test.timer.mean"].should eq("5")
      result["stats.timers.test.timer.upper"].should eq("10")
      result["stats.timers.test.timer.upper_90"].should eq("9")
      result["stats.timers.test.timer.count"].should eq("10")
    end
  end # describe carbon_update_str
end
