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
          attached_volumes = @ec2.client.describe_volumes(filters: [{ instance_id: message['instance_id'] }])[:volume_set].map { |volume| volume[:volume_id] } if message['remove_volumes']
          instance.terminate unless [:shutting_down, :terminated].include?(instance.status)
          @logger.info("Instance #{message['id']} - name: #{message['hostname']}.#{message['domain']} #{instance.id} terminated")

          if message['remove_volumes']
            attached_volumes.each do |volume_id|
              @ec2.client.delete_volume(volume_id: volume_id)
              @logger.info("Volume: #{volume_id} attached to instance: #{message['instance_id']} has been deleted")
            end
          end
        else
          @logger.info("Instance #{message['id']} - name: #{message['hostname']}.#{message['domain']} #{instance.id} not found")
        end
        @publisher.publish message.merge('terminated' => true)
      end
    end
  end
end
