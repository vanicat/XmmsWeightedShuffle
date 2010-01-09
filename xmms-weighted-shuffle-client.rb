#!/usr/bin/env ruby

require 'glib2'

require 'xmmsclient'
require 'xmmsclient/async'
require 'xmmsclient_glib'


def debug(*arg)
  puts(*arg)
end

module WeightedShuffle

  class Config
    attr_reader :colls, :playlist_name, :history, :upcoming

    # will be read in configuration in some futur time
    def initialize
      @colls = [
                { "name" => "2-rated", "mult" => 4 },
                { "name" => "3-rated", "mult" => 8 },
                { "name" => "4-rated", "mult" => 16 },
                { "name" => "5-rated", "mult" => 32 },
                { "name" => "not-rated", "expr" => "in:not-rated AND not in:bad", "mult" => 6 }
               ]

      @playlist_name = "weighted_shuffle_playlist"

      @history = 3
      @upcoming = 18
    end
  end

  class Client
    attr_reader :xc, :colls, :config, :length, :pos, :playlist

    def initialize(config)
      srand
      @config = config
      @current = false
      @pos = 0
      @length = 0
      @adding = false
      @removing = false
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

      xc.playback_status do |res|
        #Here all stage 1 for colls are done
        xc.playback_status do |res|
          #here all stage 2 for colls are done, and stage 3 will be done before callback for the next command
          initialize_playlist
        end
      end
    end

    def add_coll v
      if v["expr"] then
        coll=Xmms::Collection.parse(v["expr"])
        load_coll(v["name"], coll, v["mult"])
      else
        xc.coll_get(v["name"]) do |coll|
          if(coll.is_a?(Xmms::Collection)) then
            load_coll(v["name"], coll, v["mult"])
          else
            puts "Problem with collection #{v["name"]}"
            puts "Please make sure it exists."
            exit
          end
        end
      end
    end

    def load_coll(name,coll,mult)
      @xc.coll_query_ids(coll) do |ids_list|
        if ids_list then
          @colls.push({:name => name, :coll => coll, :mult => mult, :size => ids_list.length})
        else
          puts "Problem with collection #{name}"
          puts "Please make sure it exists, or that its expression is correct"
          exit
        end
        false
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
        true
      end

      @playlist.current_pos do |cur|
        set_pos cur[:position] if cur[:name] == config.playlist_name
        true
      end

      @xc.broadcast_playlist_current_pos do |cur|
        set_pos cur[:position] if cur[:name] == config.playlist_name
        true
      end

      @xc.broadcast_playlist_changed do |cur|
        if cur[:name] == config.playlist_name then
          @playlist.entries do |entries|
            set_length entries.length
          end
        end
        true
      end
    end

    def change_playlist pl
      @current = pl == config.playlist_name
    end

    def current?
      @current
    end

    def set_length new_length
      debug "set_length #{new_length}"
      @length = new_length
      may_add_song
    end

    def set_pos new_pos
      debug "set_pos #{new_pos}"
      @pos = new_pos || 0
      may_add_song
      may_remove_song
    end

    def rand_colls
      # look for the total number
      max = colls.inject(0) do |acc,coll|
        acc + coll[:mult] * coll[:size]
      end
      num = rand(max)
      coll = colls.find do |coll|
        num = num - coll[:mult] * coll[:size]
        num < 0
      end
      return coll
    end

    def rand_song(&block)
      coll = rand_colls()
      num = rand(coll[:size])
      xc.coll_query_ids(coll[:coll], ["id"], num, 1, &block)
    end

    def may_add_song
      unless @adding or @length - @pos >= config.upcoming
        @adding = true
        rand_song do |ids|
          unless ids.empty?
            playlist.add_entry(ids[0]) do |res|
              @adding = false
              true
            end
          else
            @adding = false
          end
          true
        end
      end
    end

    def may_remove_song
      if not @removing and @pos > config.history then
        @removing = true
        playlist.remove_entry(1) do |res|
          @removing = false
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
