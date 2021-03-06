require File.dirname(__FILE__) + '/../spec_helper'

describe "Intergration restart" do
  before :each do
    start_controller do
      @controller.load_erb(fixture("dsl/integration.erb"))
    end

    @processes.size.should == 3
    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @samples = @controller.all_groups.detect{|c| c.name == 'samples'}
  end

  after :each do
    stop_controller
  end

  it "restart process group samples" do
    @controller.command(:restart, "samples")
    sleep 11 # while they restarting

    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should_not == @old_pid1
    @p2.pid.should_not == @old_pid2
    @p3.pid.should == @old_pid3
  end

  it "restart process" do
    @controller.command(:restart, "sample1")
    sleep 10 # while they restarting

    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should_not == @old_pid1
    @p2.pid.should == @old_pid2
    @p3.pid.should == @old_pid3
  end

  it "restart process with signal" do
    should_spend(3, 0.3) do
      c = Celluloid::Condition.new
      @controller.command(:restart, "sample1", :signal => c)
      c.wait
    end

    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should_not == @old_pid1
  end

  it "restart process forking" do
    @controller.command(:restart, "forking")
    sleep 11 # while they restarting

    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should == @old_pid1
    @p2.pid.should == @old_pid2
    @p3.pid.should_not == @old_pid3

    @p1.scheduler_last_reason.should == 'monitor by user'
    @p3.scheduler_last_reason.should == 'restart by user'
  end

  it "restart forking named child" do
    @p3.wait_for_condition(15, 0.3) { @p3.children.size == 3 }
    @children = @p3.children.keys
    @children.size.should == 3
    dead_pid = @children.sample

    @controller.command(:restart, "child-#{dead_pid}").should == {:result => ["int:forking:child-#{dead_pid}"]}
    sleep 11 # while it

    new_children = @p3.children.keys
    new_children.size.should == 3
    new_children.should_not include(dead_pid)
    (@children - [dead_pid]).each do |pid|
      new_children.should include(pid)
    end

    @p3.scheduler_history.states.should include("restart_child")
  end

  it "restart missing" do
    @controller.command(:restart, "blabla").should == {:result => []}
    sleep 1
    @processes.map{|c| c.state_name}.uniq.should == [:up]
    @p1.pid.should == @old_pid1
    @p2.pid.should == @old_pid2
    @p3.pid.should == @old_pid3
  end

end
