require 'spec_helper'
require_relative '../../../../lib/wonga/pantry/ec2_delete_command_handler'

describe Wonga::Pantry::Ec2DeleteCommandHandler do
  let(:publisher) { instance_double('Wonga::Publisher').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  let(:ec2) { instance_double('AWS::EC2') }
  let(:instance) { instance_double('AWS::EC2::Instance', id: 'i-00001234', exists?: true, status: :running) }

  subject do
    described_class.new(publisher, logger, ec2)
  end

  it_behaves_like 'handler'

  describe '#handle_message' do
    before(:each) do
      allow(AWS::EC2).to receive(:new).and_return(ec2)
      allow(ec2).to receive(:instances).and_return({'i-00001234' => instance})
      allow(instance).to receive(:terminate).and_return(true)
    end

    context 'instance exists' do
      before(:each) do
        allow(instance).to receive(:exists?).and_return(true)
      end

      context 'is not terminating or terminated' do

        it 'calls instance.terminate' do
          expect(instance).to receive(:terminate).and_return(nil) # even on success returns nil
          subject.handle_message({'instance_id'=>'i-00001234'})
        end
      end

      context 'is terminating' do
        let(:instance) { instance_double('AWS::EC2::Instance', id: 'i-00001234', exists?: true, status: :shutting_down) }

        it 'does not call instance.terminate' do
          expect(instance).to_not receive(:terminate)
          subject.handle_message({'instance_id'=>'i-00001234'})
        end
      end

      context 'is terminated' do
        let(:instance) { instance_double('AWS::EC2::Instance', id: 'i-00001234', exists?: true, status: :terminated) }

        it 'does not call instance.terminate' do
          expect(instance).to_not receive(:terminate)
          subject.handle_message({'instance_id'=>'i-00001234'})
        end
      end

      it 'publishes a terminated event message' do
        expect(publisher).to receive(:publish).with({'instance_id' => 'i-00001234', 'terminated' => true})
        subject.handle_message({'instance_id'=>'i-00001234'})
      end
    end

    context 'instance does not exist' do
      let(:instance) { instance_double('AWS::EC2::Instance', id: 'i-00001234', exists?: false) }

      it 'does not call instance.terminate' do
        expect(instance).to_not receive(:terminate)
        subject.handle_message({'instance_id'=>'i-00001234'})
      end

      it 'publishes a terminated event message' do
        expect(publisher).to receive(:publish).with({'instance_id' => 'i-00001234', 'terminated' => true})
        subject.handle_message({'instance_id'=>'i-00001234'})
      end
    end
  end
end

