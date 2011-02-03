#--
# Copyright (c) 2011 David Kellum
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

    # Yields self to block (for scoping convenience)
    def with( scp = :default )
      prior, @scope = @scope, scp
      yield self
    ensure
      @scope = prior
    end

    alias :scope :with

    # Add hook block by specified hook key. Will only be executed when
    # apply or inject is later called with the same key.  Multiple
    # hook blocks for the same key will be called in the order added.
    def add( key, &block )
      applied.delete( sk( key ) )
      hooks[ sk( key ) ] << [ block, caller[0].to_s ]
    end

    alias :setup :add

    # Pass the specified value to each previously added proc with
    # matching key. Returns (typically mutated) value.
    def apply( key, value )
      applied << sk( key )
      hooks[ sk( key ) ].each { |hook| hook[0].call( value ) }
      value
    end

    # Inject value (or nil) into the chain of previously added procs,
    # which should implement binary operations (i.e. return desired
    # value), and return the last value from the last proc.
    def inject( key, value = nil )
      applied << sk( key )
      hooks[ sk( key ) ].inject( value ) { |v, hook| hook[0].call( v ) }
    end

    # Merge returned values from each added proc to the initial value
    def merge( key, value = {} )
      applied << sk( key )
      hooks[ sk( key ) ].inject( value ) { |v, hook| v.merge( hook[0].call ) }
    end

    # Load the specified file via Kernel.load, with a log message if
    # set.
    def load_file( file )
      log "Loading file #{file}."
      load( file, true ) #wrap in in anonymous module
    end

    # Register -c/--config flags on given OptionParser to load_file
    def register_config( opts )
      opts.on( "-c", "--config FILE", "Load configuration file") do |file|
        load_file( file )
      end
    end

    # Register to yield log messages to the given block.
    def log_with( &block )
      @logger = block
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

    # Yields [ [ scope, key ], [ callers ] ] to block for each hook
    # key added but not applied.  Often this suggests a typo or other
    # mistake by the hook Proc author.
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
