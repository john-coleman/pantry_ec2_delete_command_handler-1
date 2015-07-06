require 'spec_helper'
require 'wonga/daemon/publisher'
require 'logger'
require_relative '../../../../lib/wonga/pantry/ec2_delete_command_handler'

RSpec.describe Wonga::Pantry::Ec2DeleteCommandHandler do
  let(:publisher) { instance_double(Wonga::Daemon::Publisher).as_null_object }
  let(:logger) { instance_double(Logger).as_null_object }
  let(:ec2) { Aws::EC2::Resource.new }
  let(:client) { ec2.client }
  let(:response) { { reservations: [{ instances: [{ instance_id: instance_id, state: { name: ec2_status } }] }] } }
  let(:instance_id) { 'i-00001234' }
  let(:ec2_status) { 'running' }

  subject do
    described_class.new(publisher, logger, ec2)
  end

  before(:each) do
    client.stub_responses :describe_instances, response
    allow(client).to receive(:terminate_instances).and_call_original
  end

  it_behaves_like 'handler'

  describe '#handle_message' do
    context 'instance exists' do
      context 'is not terminating or terminated' do
        it 'calls instance.terminate' do
          subject.handle_message('instance_id' => instance_id)
          expect(client).to have_received(:terminate_instances)
        end
      end

      context 'is terminating' do
        let(:ec2_status) { 'shutting_down' }

        it 'does not call instance.terminate' do
          subject.handle_message('instance_id' => instance_id)
          expect(client).not_to have_received(:terminate_instances)
        end
      end

      context 'is terminated' do
        let(:ec2_status) { 'terminated' }

        it 'does not call instance.terminate' do
          subject.handle_message('instance_id' => instance_id)
          expect(client).not_to have_received(:terminate_instances)
        end
      end

      context 'attached volumes' do
        let(:volumes) { [{ volume_id: 'vol-21083656', snapshot_id: 'snap-b4ef17a9' }, { volume_id: 'vol-222222' }] }

        before(:each) do
          client.stub_responses :describe_volumes, volumes: volumes
          allow(client).to receive(:describe_volumes).with(filters: [name: 'attachment.instance-id', values: [instance_id]]).and_call_original
        end

        it 'should remove attached volumes when remove_volumes is set' do
          expect(client).to receive(:delete_volume).with(volume_id: volumes.first[:volume_id]).and_call_original
          expect(client).to receive(:delete_volume).with(volume_id: volumes.last[:volume_id]).and_call_original
          subject.handle_message('remove_volumes' => true, 'instance_id' => instance_id)
        end

        it 'should not remove attached volumes' do
          expect(client).to_not receive(:delete_volume)
          subject.handle_message('instance_id' => instance_id)
        end
      end

      it 'publishes a terminated event message' do
        expect(publisher).to receive(:publish).with('instance_id' => instance_id, 'terminated' => true)
        subject.handle_message('instance_id' => instance_id)
      end
    end

    context 'instance does not exist' do
      let(:response) { 'InvalidInstanceIDNotFound' }

      it 'does not call instance.terminate' do
        subject.handle_message('instance_id' => instance_id)
      end

      it 'publishes a terminated event message' do
        expect(publisher).to receive(:publish).with('instance_id' => instance_id, 'terminated' => true)
        subject.handle_message('instance_id' => instance_id)
      end
    end
  end
end
