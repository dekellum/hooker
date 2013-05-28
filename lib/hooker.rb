#--
# Copyright (c) 2011-2013 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You may
# obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'hooker/base'

# A registry of hooks, added and applied for indirect configuration
# support.
module Hooker

  class << self

    # Yields self under the given scope to block.
    def with( scp = :default )
      prior, @scope = @scope, scp
      yield self
    ensure
      @scope = prior
    end

    # Add hook block by specified hook key. Will only be executed when
    # apply, inject, or merge is later called with the same key.
    # Multiple hook blocks for the same key will be called in the
    # order added.
    def add( key, clr = nil, &block )
      applied.delete( sk( key ) )
      hooks[ sk( key ) ] << [ block, ( clr || caller.first ).to_s ]
    end

    # Allow method setup_<foo> as alias for add( :foo )
    def method_missing( method, *args, &block )
      if method.to_s =~ /^setup_(.*)$/ && args.empty?
        add( $1.to_sym, caller.first, &block )
      else
        super
      end
    end

    # Pass the specified initial value to each previously added Proc
    # with matching key and returns the mutated value.
    def apply( key, value )
      applied << sk( key )
      hooks[ sk( key ) ].each { |hook| hook[0].call( value ) }
      value
    end

    # Inject value (or nil) into the chain of previously added Procs,
    # which should implement binary operations, returning desired
    # value. Returns the last value from the last proc.
    def inject( key, value = nil )
      applied << sk( key )
      hooks[ sk( key ) ].inject( value ) { |v, hook| hook[0].call( v ) }
    end

    # Merge returned values from each added Proc to the initial value
    # (or empty Hash).
    def merge( key, value = {} )
      applied << sk( key )
      hooks[ sk( key ) ].inject( value ) { |v, hook| v.merge( hook[0].call ) }
    end

    # Register to yield log messages to the given block.
    def log_with( &block )
      @logger = block
    end

    # Load the specified file via Kernel.load, with a log message if
    # set.
    def load_file( file )
      log "Loading file #{file}"

      # Workaround for some odd load behavior when not a regular file.
      IO.read( file )

      load( file, true ) #wrap in in anonymous module
    end

    # Register -c/--config flags on given OptionParser to load_file
    def register_config( opts )
      opts.on( "-c", "--config FILE", "Load configuration file" ) do |file|
        load_file( file )
      end
    end

    # Log results of check_not_applied, one message per not applied
    # hook.
    def log_not_applied
      check_not_applied do |rkey, calls|
        k = rkey.map { |s| s.inspect }.compact.join( ', ' )
        msg = "Hook #{k} was never applied. Added from:\n"
        calls.each { |cl| msg += "  - #{cl}\n" }
        log msg
      end
    end

    # Yields [ [ scope, key ], [ caller, ... ] ] to block for each
    # hook key added but not applied.  Often this suggests a typo or
    # other mistake by the hook Proc author.
    def check_not_applied
      ( hooks.keys - applied ).each do |rkey|
        calls = hooks[ rkey ].map { |blk, clr| clr }
        yield( rkey, calls )
      end
    end

    private

    # Hash of hook keys to array of procs.
    def hooks
      @hooks ||= Hash.new { |h, k| h[k] = [] }
    end

    # List of hook keys that were applied thus far
    def applied
      @applied ||= []
    end

    # Clears all Hooker state.
    def clear
      @hooks = nil
      @applied = nil
      @logger = nil
    end

    def log( msg )
      @logger.call( msg ) if @logger
    end

    def sk( key )
      if key.is_a?( Array ) && ( key.length == 2 )
        key
      else
        [ @scope, key ]
      end
    end

  end

  @scope = :default

end
