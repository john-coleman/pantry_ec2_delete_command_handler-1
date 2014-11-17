#!/usr/bin/env ruby

require 'rubygems'
require 'wonga/daemon'
require_relative 'lib/wonga/pantry/ec2_delete_command_handler'

dir_name = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
Wonga::Daemon.load_config(File.expand_path(File.join(dir_name, 'config/daemon.yml')))
Wonga::Daemon.run(Wonga::Pantry::Ec2DeleteCommandHandler.new(Wonga::Daemon.publisher, Wonga::Daemon.logger))
