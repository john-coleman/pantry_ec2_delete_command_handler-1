require 'spec_helper'
require_relative '../../../../lib/wonga/pantry/ec2_delete_command_handler'

describe Wonga::Pantry::Ec2DeleteCommandHandler do
  let(:publisher) { instance_double('Wonga::Publisher').as_null_object }
  let(:logger) { instance_double('Logger').as_null_object }
  let(:ec2) { AWS::EC2.new }
  let(:instance) { instance_double('AWS::EC2::Instance', id: 'i-00001234', exists?: true, status: :running) }
  let(:client) { ec2.client }

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

      context 'attached volumes' do
        let(:instance) { instance_double('AWS::EC2::Instance', id: 'i-00001234', exists?: true, status: :shutting_down) }
        let(:volume) { [{ volume_id: 'vol-21083656', snapshot_id: 'snap-b4ef17a9'}, { volume_id: 'vol-222222'}] }
        before(:each) do
          allow(client).to receive(:describe_volumes).with(filters: [{ instance_id: instance.id }]).and_return(volume_set: volume)
        end

        it 'should remove attached volumes when remove_volumes is set' do
          expect(client).to receive(:delete_volume).with(volume_id: volume.first[:volume_id])
          expect(client).to receive(:delete_volume).with(volume_id: volume.last[:volume_id])
          subject.handle_message({'remove_volumes'=>true, 'instance_id'=>'i-00001234'})
        end

        it 'should not remove attached volumes' do
          expect(client).to_not receive(:delete_volume)
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

