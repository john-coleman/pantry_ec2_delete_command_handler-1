require 'aws-sdk'
module Wonga
  module Pantry
    class Ec2DeleteCommandHandler
      def initialize(publisher, logger, ec2 = Aws::EC2::Resource.new)
        @ec2 = ec2
        @publisher = publisher
        @logger = logger
      end

      def handle_message(message)
        instance = @ec2.instance message['instance_id']
        if instance.exists?
          instance.terminate unless %w(shutting_down terminated).include?(instance.state.name)
          @logger.info("Instance #{message['id']} - name: #{message['hostname']}.#{message['domain']} #{instance.id} terminated")

          delete_volumes(message['instance_id']) if message['remove_volumes']
        else
          @logger.info("Instance #{message['id']} - name: #{message['hostname']}.#{message['domain']} #{instance.id} not found")
        end
        @publisher.publish message.merge('terminated' => true)
      end

      private

      def delete_volumes(instance_id)
        @ec2.volumes(filters: [{ name: 'attachment.instance-id', values: [instance_id] }]).each(&:delete)
      end
    end
  end
end
