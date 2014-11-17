module Wonga
  module Pantry
    class Ec2DeleteCommandHandler
      def initialize(publisher, logger, ec2 = AWS::EC2.new)
        @ec2 = ec2
        @publisher = publisher
        @logger = logger
      end

      def handle_message(message)
        instance = @ec2.instances[message['instance_id']]
        if instance.exists?
          instance.terminate unless [:shutting_down, :terminated].include?(instance.status)
          @logger.info("Instance #{message['id']} - name: #{message['hostname']}.#{message['domain']} #{instance.id} terminated")

          delete_volumes(message['instance_id']) if message['remove_volumes']
        else
          @logger.info("Instance #{message['id']} - name: #{message['hostname']}.#{message['domain']} #{instance.id} not found")
        end
        @publisher.publish message.merge('terminated' => true)
      end

      private

      def delete_volumes(instance_id)
        attached_volumes = @ec2.client.describe_volumes(filters: [{ name: 'attachment.instance-id', values: [instance_id] }])[:volume_set].map do |volume|
          volume[:volume_id]
        end

        attached_volumes.each do |volume_id|
          begin
            @ec2.client.delete_volume(volume_id: volume_id)
            @logger.info("Volume: #{volume_id} attached to instance: #{instance_id} has been deleted")
          rescue AWS::EC2::Errors::InvalidVolume::NotFound
            @logger.info("Volume: #{volume_id} attached to instance: #{instance_id} has been already deleted")
          end
        end
      end
    end
  end
end
