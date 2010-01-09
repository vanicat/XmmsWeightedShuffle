#!/usr/bin/env ruby

require 'glib2'

require 'xmmsclient'
require 'xmmsclient/async'
require 'xmmsclient_glib'


begin
	xmms = Xmms::Client::Async.new('PLaylistClient').connect(ENV['XMMS_PATH'])
rescue Xmms::Client::ClientError
	puts 'Failed to connect to XMMS2 daemon.'
	puts 'Please make sure xmms2d is running and using the correct IPC path.'
	exit
end

xmms.add_to_glib_mainloop

ml = GLib::MainLoop.new(nil, false)

ml.run
