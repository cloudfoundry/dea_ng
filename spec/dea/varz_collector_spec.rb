# coding: UTF-8

require "spec_helper"
require "dea/varz_collector"

describe Dea::VarzCollector do
  let(:bootstrap) do
    bootstrap = Dea::Bootstrap.new
    bootstrap.setup_instance_registry
    bootstrap.setup_resource_manager

    6.times do |ii|
      instance = Dea::Instance.new(bootstrap,
                                   "application_id" => ii,
                                   "runtime_name"   => "runtime#{ii % 2}",
                                   "framework_name" => "framework#{ii % 2}",
                                   "limits"         => {
                                     "disk" => ii,
                                     "mem"  => ii * 1024})
      instance.stub(:used_memory).and_return(ii)
      instance.stub(:used_disk).and_return(ii)
      instance.stub(:computed_pcpu).and_return(ii)
      bootstrap.instance_registry.register(instance)
    end

    bootstrap
  end

  let(:collector) { Dea::VarzCollector.new(bootstrap) }

  describe "update" do
    before :each do
      VCAP::Component.instance_variable_set(:@varz, {})
      collector.update
    end

    it "should compute aggregate memory statistics" do
      mem_used = bootstrap.instance_registry.inject(0) { |a, i| a + i.used_memory }
      VCAP::Component.varz[:apps_used_memory].should == mem_used
    end

    it "should compute memory/disk/cpu statistics by framework" do
      summary = compute_summaries(bootstrap.instance_registry, :framework_name)
      VCAP::Component.varz[:frameworks].should == summary
    end

    it "should compute memory/disk/cpu statistics by runtime" do
      summary = compute_summaries(bootstrap.instance_registry, :runtime_name)
      VCAP::Component.varz[:runtimes].should == summary
    end
  end

  def compute_summaries(instances, group_by)
    summaries = Hash.new do |h, k|
      h[k] = {
        :used_memory     => 0,
        :reserved_memory => 0,
        :used_disk       => 0,
        :used_cpu        => 0,
      }
    end

    instances.each do |i|
      summary = summaries[i.send(group_by)]
      summary[:used_memory] += i.used_memory
      summary[:reserved_memory] += i.attributes["limits"]["mem"] / 1024
      summary[:used_disk] += i.used_disk
      summary[:used_cpu] += i.computed_pcpu
    end

    summaries
  end
end
