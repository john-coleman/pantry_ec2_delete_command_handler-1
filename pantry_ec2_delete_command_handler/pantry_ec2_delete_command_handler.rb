module Wonga
  module Daemon
    class PantryEc2DeleteCommandHandler
      def initialize(publisher, logger)
        @publisher = publisher
        @logger = logger
      end

      def handle_message(message)
        ec2 = AWS::EC2.new
        instance = ec2.instances[message['instance_id']]
        instance.terminate if instance.exists?
        @publisher.publish message.merge('status' => 'deleted')
      end
    end
  end
end
