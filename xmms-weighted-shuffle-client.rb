#!/usr/bin/env ruby

require 'glib2'

require 'xmmsclient'
require 'xmmsclient/async'
require 'xmmsclient_glib'


def debug(arg)
  puts(arg)
end

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
    attr_reader :coll, :mult, :size
    def initialize(coll_val, size_val, mult_val)
      @coll = coll_val
      @mult = mult_val
      @size = size_val
    end
  end

  class Client
    attr_reader :xc, :colls, :config, :length, :pos, :playlist

    def initialize(config)
      @config = config
      @current = false
      @pos = 0
      @length = 0
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
        add_coll v
        false
      end

      @playlist = @xc.playlist(config.playlist_name)

      initialize_playlist

    end

    def add_coll v
      @xc.coll_get(v["name"]) do |coll|
        if(coll.is_a?(Xmms::Collection)) then
          @xc.coll_query_ids(coll) do |ids_list|
            @colls.push(Collection.new(coll, ids_list.length, v["mult"]))
            false
          end
        else
          puts "Problem with collection #{v["name"]}"
          puts "Please make sure it exists."
          exit
        end
      end
    end

    def initialize_playlist
      @xc.playlist_current_active do |pl|
        change_playlist pl
        true
      end

      @xc.broadcast_playlist_loaded do |pl|
        change_playlist pl
        true
      end

      @playlist.entries do |entries|
        set_length entries.length
      end

      @playlist.current_pos do |cur|
        set_pos cur
      end

      @xc.broadcast_playlist_current_pos do |cur|
        set_pos cur[:position] if cur[:name] == config.playlist_name
      end
    end

    def change_playlist pl
      @current = pl == config.playlist_name
    end

    def current?
      @current
    end

    def set_length new_length
      @length = new_length
      if @length - @pos < config.upcoming and current? then
        # here we will fill the playlist
      end
    end

    def set_pos new_pos
      @pos = new_pos || 0
      if @length - @pos < config.upcoming and current? then
        # here we will remove what needed
      end
    end

    def run()
      @ml.run
    end
  end

  Client.new(Config.new()).run()
end
