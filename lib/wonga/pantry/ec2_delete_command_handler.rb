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
        else
          @logger.info("Instance #{message['id']} - name: #{message['hostname']}.#{message['domain']} #{instance.id} not found")
        end
        @publisher.publish message.merge('terminated' => true)
      end
    end
  end
end
