#!/usr/bin/env ruby

require 'glib2'

require 'xmmsclient'
require 'xmmsclient/async'
require 'xmmsclient_glib'

module WeightedShuffle

  class Config
    attr_reader :colls, :playlist_name, :history, :upcoming

    # will be read in configuration in some futur time
    def initialize
      @colls = [
                { "name" => "1-rated", "mult" => 0 },
                { "name" => "2-rated", "mult" => 1 },
                { "name" => "3-rated", "mult" => 2 },
                { "name" => "4-rated", "mult" => 4 },
                { "name" => "5-rated", "mult" => 8 },
                { "name" => "not-rated", "mult" => 2 }
               ]

      @playlist_name = "weighted_shuffle_playlist"

      @history = 3
      @upcoming = 18
    end
  end

  class Collection
    attr_reader :coll, :mult, :count
    def initialize(coll_val, mult_val,count_val)
      @coll = coll_val
      @mult = mult_val
      @count = count_val
    end
  end

  class Client
    attr_reader :xc, :colls, :config

    def initialize(config)
      @config = config
      begin
        @xc = Xmms::Client::Async.new('PLaylistClient').connect(ENV['XMMS_PATH'])
      rescue Xmms::Client::ClientError
        puts 'Failed to connect to XMMS2 daemon.'
        puts 'Please make sure xmms2d is running and using the correct IPC path.'
        exit
      end
      @xc.add_to_glib_mainloop
      @ml = GLib::MainLoop.new(nil, false)

      @colls = []

      @config.colls.each do |v|
        xc.coll_get(v["name"]) do |coll|
          if(coll.is_a?(Xmms::Collection)) then
            xc.coll_query_ids(coll) do |ids_list|
              @colls.push( Collection.new(coll, ids_list.length, v["mult"]) )
              false
            end
          else
            puts "Problem with collection #{v["name"]}"
            puts "Please make sure it exists."
            exit
          end
          false
        end
      end
    end

    def run()
      @ml.run
    end
  end

  Client.new(Config.new()).run()
end
