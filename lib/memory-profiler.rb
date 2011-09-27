#!/usr/bin/ruby --
# vim: tabstop=2:softtabstop=2:shiftwidth=2:noexpandtab
=begin

  Author:  Matthew Kerwin  <matthew@kerwin.net.au>
  Version: 1.0.1
  Date:    2011-01-31


  Copyright 2011 Matthew Kerwin.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

=end

require 'sync'

module MemoryProfiler
        DEFAULTS = {
                # general options
                :sort_by  => :current,
                :only     => [],
                :ignore   => [],
                :limit    => 20,
                :force_gc => false,
                # daemon options
                :delay    => 60,
                :filename => nil,
                # ObjectSpaceAnalyser options
                :string_debug  => false,
                :marshall_size => false,
        }
        @@daemon_thread = nil
        @@daemon_sync = Sync.new

        @@start_data = nil
        @@start_sync = Sync.new

        #
        # Begins an analysis thread that runs periodically, reporting to a text
        # file at:  /tmp/memory_profiler-<pid>.log
        #
        # Returns the filename used.
        #
        # Options:
        #   :delay  => 60     # number of seconds between summaries
        #   :filename => nil  # override the generated default
        # See: #start for other options
        #
        def self.start_daemon(opt = {})
                opt = DEFAULTS.merge(opt)
                filename = opt[:filename] || "/tmp/memory_profiler-#{Process.pid}.log"
                @@daemon_sync.synchronize(:EX) do
                        raise 'daemon process already running' if @@daemon_thread
                        @@daemon_thread = Thread.new do
                                prev = Hash.new(0)
                                file = File.open(filename, 'w')
                                loop do
                                        begin
                                                GC.start if opt[:force_gc]
                                                curr = ObjectSpaceAnalyser.analyse(opt)
                                                data = self._delta(curr, prev, opt)

                                                file.puts '-'*80
                                                file.puts Time.now.to_s
                                                data.each {|k,c,d| file.printf( "%5d %+5d %s\n", c, d, k.name ) }

                                                prev = curr
                                                GC.start if opt[:force_gc]
                                        rescue ::Exception => err
                                                $stderr.puts "** MemoryProfiler daemon error: #{err}", err.backtrace.map{|b| "\t#{b}" }
                                        end
                                        sleep opt[:delay]
                                end #loop
                        end #Thread.new
                end
                filename
        end

        #
        # Terminates the analysis thread started by #start_daemon
        #
        def self.stop_daemon
                @@daemon_sync.synchronize(:EX) do
                        raise 'no daemon process running' unless @@daemon_thread
                        @@daemon_thread.kill
                        @@daemon_thread.join
                        @@daemon_thread = nil
                end
                self
        end

        #
        # Generates an instantaneous report on the current Ruby ObjectSpace, saved to
        # a text file at:  /tmp/memory_profiler-<pid>-<time>.log
        #
        # Returns the filename used.
        #
        # See: #start for valid/default options, except that :sort_by may
        # only have the value :current or :none when using #report
        #
        def self.report(opt = {})
                opt = DEFAULTS.merge(opt)
                GC.start if opt[:force_gc]

                data = ObjectSpaceAnalyser.analyse(opt)

                if opt[:sort_by] == :current
                        data = data.to_a.sort_by{|k,v| -v }
                        data = data[0,opt[:limit]] if opt[:limit] > 0 and opt[:limit] < data.length
                elsif opt[:sort_by] != :none
                        warn "MemoryProfiler: invalid option :sort_by => #{opt[:sort_by].inspect}; using :none"
                end

                filename = opt[:filename] || "/tmp/memory_profiler-#{Process.pid}-#{Time.now.to_i}.log"
                File.open(filename, 'w') do |f|
                        data.each {|k,c| f.printf( "%5d %s\n", c, k.name ) }
                end

                GC.start if opt[:force_gc]
                filename
        end

        #
        # If a block is given, executes it and returns a summary.  Otherwise,
        # starts the analyser, and waits for a call to #restart or #stop.
        #
        # Returned data is an array of:
        #    [  [Class, current_usage, usage_delta],  ...  ]
        #
        # Options:
        #   :sort_by       => :current  # how to order classes;  :current | :delta | :absdelta | :none
        #   
        #   :only          => []        # list of only classes to scan;  if empty, scans all classes
        #   :ignore        => []        # list of classes to exclude from reports (including sub-classes and modules, but not namespaces)
        #   :limit         => 20        # how many of the top classes to report (less than 1 means 'all'); only matters if :sort_by is not :none
        #   
        #   :force_gc      => true      # if true, forces a garbage collection before and after generating report
        #   
        #   :string_debug  => false     # see ObjectSpaceAnalyser#analyse
        #   :marshall_size => false     # see ObjectSpaceAnalyser#analyse
        #
        def self.start(opt = {}, &block)
                opt = DEFAULTS.merge(opt)
                if block_given?
                        # get pre-block analysis of ObjectSpace
                        GC.start if opt[:force_gc]
                        prev = ObjectSpaceAnalyser.analyse(opt)
                        GC.start if opt[:force_gc]

                        yield

                        # get post-block analysis of ObjectSpace
                        GC.start if opt[:force_gc]
                        curr = ObjectSpaceAnalyser.analyse(opt)

                        # calculate the differences before and after execution
                        data = self._delta(curr, prev, opt)

                        # return it
                        GC.start if opt[:force_gc]
                        data
                else
                        @@start_sync.synchronize(:EX) do
                                raise 'already started' if @@start_data

                                GC.start if opt[:force_gc]
                                @@start_data = [ObjectSpaceAnalyser.analyse(opt), opt]
                                GC.start if opt[:force_gc]
                        end
                        self
                end
        end

        #
        # Stops the current analysis and emits the results.
        #
        # See: #start
        #
        def self.stop
                prev = nil
                opt  = nil
                @@start_sync.synchronize(:EX) do
                        raise 'not started' unless @@start_data
                        prev, opt = @@start_data
                        @@start_data = nil
                end

                # get the current state of affairs
                GC.start if opt[:force_gc]
                curr = ObjectSpaceAnalyser.analyse(opt)

                # calculate the differences before and after execution
                data = self._delta(curr, prev, opt)

                # return it
                GC.start if opt[:force_gc]
                data
        end

        #
        # Stops the current analysis, emits the results, and immediately starts
        # a new analysis.
        #
        # See: #stop, #start
        #
        def self.restart(opt = {})
                res = self.stop
                self.start(opt)
                res
        end

        #  => [ [Class, current, delta], ... ]
        def self._delta(curr, prev, opt={}) #:nodoc:
                opt = DEFAULTS.merge(opt)

                # determine the difference between current and previous
                delta = Hash.new(0)
                (curr.keys + prev.keys).each do |k|
                        delta[k] = curr[k] - prev[k]
                end
                data = delta.map{|k,d| [k, curr[k].to_i, d]}

                # organise data according to given options
                case opt[:sort_by]
                when :none
                        opt[:limit] = -1
                when :current
                        data = data.sort_by{|k,c,d| -( c ) }
                when :delta
                        data = data.sort_by{|k,c,d| -( d ) }
                when :absdelta
                        data = data.sort_by{|k,c,d| -( d.abs ) }
                else
                        warn "MemoryProfiler: invalid option :sort_by => #{opt[:sort_by].inspect}; using :none"
                        opt[:limit] = -1
                end
                data = data[0,opt[:limit]] if opt[:limit] > 0 and opt[:limit] < data.length

                # return it
                data
        end

        #
        # Formats data, such as that returned by #start , into a printable,
        # readable string.
        #
        def self.format(data)
                " Curr. Delta Class\n" +
                " ----- ----- -----\n" +
                data.map{|k,c,d| sprintf(" %5d %+5d %s\n", c, d, k.name) }.join
        end


        module ObjectSpaceAnalyser
                #
                # Returns a hash mapping each Class to its usage.
                #
                # If opt[:marshall_size] is true, the usage is estimated using Marshall.dump() for each instance;
                # otherwise it is a simple instance count.
                #
                # If opt[:string_debug] is true, the analyser writes a text file containing every string
                # in the Ruby ObjectSpace, at:  /tmp/memory_profiler-<pid>-strings-<time>.log
                #
                # Uses opt[:only] and opt[:ignore] , as per MemoryProfiler#start
                #
                def self.analyse(opt = {})
                        opt = MemoryProfiler::DEFAULTS.merge(opt)
                        marshall_size = !!opt[:marshall_size]
                        string_debug = !!opt[:string_debug]
                        ign  = opt[:ignore]
                        only = opt[:only]

                        res = Hash.new(0)
                        str = [] if string_debug
                        ObjectSpace.each_object do |o|
                                if res[o.class] or ((only.empty? or only.any?{|y| o.is_a? y }) and ign.none?{|x| o.is_a? x })
                                        res[o.class] += (marshall_size ? self.__sizeof(o) : 1)
                                end
                                str.push o.inspect if string_debug and o.class == String
                        end
                        if string_debug
                                self.__save str
                                str = nil
                        end
                        res
                end

                # Estimates the size of an object using Marshall.dump()
                # Defaults to 1 if anything goes wrong.
                def self.__sizeof(o) #:nodoc:
                        Marshall.dump(o).size
                rescue ::Exception
                        1
                end

                # a single place where the magic filename is defined
                def self.__save(str) #:nodoc:
                        File.open("/tmp/memory_profiler-#{Process.pid}-strings-#{Time.now.to_i}.log", 'w') do |f|
                                str.sort.each{|s| f.puts s }
                        end
                        str = nil
                end
        end
end


if $0 == __FILE__
        puts MemoryProfiler.start_daemon( :limit=>5, :delay=>10, :marshall_size=>true, :sort_by=>:absdelta )

        5.times do
                blah = Hash.new([])
                rpt  = MemoryProfiler.start( :limit=>10 ) do
                        100.times{ blah[1] << 'aaaaa' }
                        1000.times{ blah[2] << 'bbbbb' }
                end
                puts MemoryProfiler.format(rpt)
                sleep 7
        end

        MemoryProfiler.stop_daemon
end
