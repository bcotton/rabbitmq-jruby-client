require 'rubygems'
require 'spec'
require File.dirname(__FILE__) + '/../lib/rabbitmq_client'

describe RabbitMQClient do
  before(:each) do
    @client = RabbitMQClient.new
  end
  
  after(:each) do
    @client.disconnect
  end
  
  it "should able to create a connection" do
    @client.connection.should_not be_nil
  end
  
  it "should able to create a channel" do
    @client.channel.should_not be_nil
  end
  
  it "should be able to create a new exchange" do
    exchange = @client.exchange('test_exchange', 'direct')
    exchange.should_not be_nil
  end
  
  # Commented out because it does not return in RSpec
  # it "should be able to delete the queue" do
  #   client = RabbitMQClient.new
  #   queue = client.queue('test_queue')
  #   exchange = client.exchange('test_exchange', 'direct')
  #   queue.delete
  #   lambda {
  #     queue.publish('Hello World')
  #   }.should raise_error
  # end
  
  describe Queue, "Basic non-persistent queue" do
    before(:each) do
      @queue = @client.queue('test_queue')
      @exchange = @client.exchange('test_exchange', 'direct')
    end
    
    it "should be able to create a queue" do
      @queue.should_not be_nil
    end
    
    it "should be able to bind to an exchange" do
      @queue.bind(@exchange).should_not be_nil
    end
    
    it "should be able to publish and retrieve a message" do
      @queue.bind(@exchange)
      @queue.publish('Hello World')
      @queue.retrieve.should == 'Hello World'
      @queue.publish('人大')
      @queue.retrieve.should == '人大'
    end
    
    it "should be able to purge the queue" do
      @queue.publish('Hello World')
      @queue.publish('Hello World')
      @queue.publish('Hello World')
      @queue.purge
      @queue.retrieve.should == nil
    end
    
    it "should able to subscribe with a callback function" do
      a = 0
      @queue.bind(@exchange)
      @queue.subscribe do |v|
         a += v.to_i
      end
      @queue.publish("1")
      @queue.publish("2")
      sleep 1
      a.should == 3
    end

    it "should able to subscribe with a 2-arity callback function" do
      a = []
      @queue.bind(@exchange)
      @queue.subscribe do |v, p|
         a << p.nil?
      end
      @queue.publish("1")
      @queue.publish("2")
      sleep 1
      a.should == [false,false]
    end

    it "should able to subscribe with a 3-arity callback function" do
      a = []
      @queue.bind(@exchange)
      @queue.subscribe do |v, p, e|
         a << e.nil?
      end
      @queue.publish("1")
      @queue.publish("2")
      sleep 1
      a.should == [false,false]
    end

    it "should be able to subscribe to a queue using loop_subscribe" do
      a = 0
      @queue.bind(@exchange)
      Thread.new do
        begin
          timeout(1) do
            @queue.loop_subscribe do |v|
              a += v.to_i
            end
          end
        rescue Timeout::Error => e
        end
      end
      @queue.publish("1")
      @queue.publish("2")
      sleep 2
      a.should == 3
    end

    it "should be able to subscribe to a queue using loop_subscribe with a 2-arity callback" do
      a = []
      @queue.bind(@exchange)
      Thread.new do
        begin
          timeout(1) do
            @queue.loop_subscribe do |v, p|
              a << p.nil?
            end
          end
        rescue Timeout::Error => e
        end
      end
      @queue.publish("1")
      @queue.publish("2")
      sleep 2
      a.should == [false,false]
    end

    it "should be able to subscribe to a queue using loop_subscribe with a 3-arity callback" do
      a = []
      @queue.bind(@exchange)
      Thread.new do
        begin
          timeout(1) do
            @queue.loop_subscribe do |v, p, e|
              a << e.nil?
            end
          end
        rescue Timeout::Error => e
        end
      end
      @queue.publish("1")
      @queue.publish("2")
      sleep 2
      a.should == [false,false]
    end

    it "should raise an exception if binding a persistent queue with non-persistent exchange and vice versa" do
      persistent_queue = @client.queue('test_queue1', true)
      persistent_exchange = @client.exchange('test_exchange1', 'fanout', true)
      lambda { persistent_queue.bind(@exchange) }.should raise_error(RabbitMQClient::RabbitMQClientError)
      lambda { @queue.bind(persistent_exchange) }.should raise_error(RabbitMQClient::RabbitMQClientError)
      persistent_queue.delete
      persistent_exchange.delete
    end
    
    it "should raise an exception if publish a persistent message on non-duration queue" do
      @queue.bind(@exchange)
      lambda { @queue.persistent_publish('Hello') }.should raise_error(RabbitMQClient::RabbitMQClientError)
    end
  end
  
  describe Queue, "Basic persistent queue" do
    before(:each) do
      @queue = @client.queue('test_durable_queue', true)
      @exchange = @client.exchange('test_durable_exchange', 'fanout', true)
    end
    
    it "should be able to create a queue" do
      @queue.should_not be_nil
    end
    
    it "should be able to bind to an exchange" do
      @queue.bind(@exchange).should_not be_nil
    end
    
    it "should be able to publish and retrieve a message" do
      @queue.bind(@exchange)
      @queue.persistent_publish('Hello World')
      @queue.retrieve.should == 'Hello World'
    end
    
    it "should be able to subscribe with a callback function" do
      a = 0
      @queue.bind(@exchange)
      @queue.subscribe do |v|
         a += v.to_i
      end
      @queue.persistent_publish("1")
      @queue.persistent_publish("2")
      sleep 1
      a.should == 3
    end
  end
end