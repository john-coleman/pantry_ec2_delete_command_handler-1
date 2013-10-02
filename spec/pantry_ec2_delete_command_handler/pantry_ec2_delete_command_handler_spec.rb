require 'spec_helper'
require_relative '../../pantry_ec2_delete_command_handler/pantry_ec2_delete_command_handler'

describe Wonga::Daemon::PantryEc2DeleteCommandHandler do
  let(:publisher) { instance_double('Wonga::Publisher').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  let(:instance) { instance_double('AWS::EC2::Instance').as_null_object }
  let(:ec2) { instance_double('AWS::EC2') }
  
  subject do 
    described_class.new(publisher, logger).as_null_object
  end
  
  it_behaves_like 'handler'
  
  describe "#handle_message" do
    before(:each) do
      AWS::EC2.stub(:new).and_return(ec2)
      ec2.stub(:instances).and_return(instance)
    end
    
    it "calls instance.terminate" do
      instance.should_receive(:terminate).and_return(nil) # even on success returns nil
      subject.handle_message({"instance_id"=>"i-6c3db923"})
    end
    
    it "publishes a deleted event" do
      publisher.stub(:publish).with({"instance_id" => "i-6c3db923", "status" => "deleted"})
      subject.handle_message({"instance_id"=>"i-6c3db923"})
    end
  end
end

