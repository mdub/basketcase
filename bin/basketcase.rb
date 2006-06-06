#! /usr/bin/env ruby

# This is an attempt to wrap up the ClearCase command-line interface
# (cleartool) to enable more CVS-like (or Subversion-like) usage of
# ClearCase.
#
# Warning: this script is EXPERIMENTAL: use AT YOUR OWN RISK
#
# @author Mike Williams

$USAGE = <<EOF
usage: basketcase <command> [<options>]

COMMANDS:

% {list,ls,status,stat}

    List element status.

    -a(ll)      Show all files. 
                (by default, up-to-date files are not reported)

    -r(ecurse)  Recursively list sub-directories.
                (by default, just lists current directory)

% update

    Update your snapshot view. 

    -nomerge    Don\'t attempt to merge in changes to checked-out files.

% {checkout,co,edit}

    Check-out an element (unreserved).

% {checkin,ci,commit}

    Check-in an element, prompting for a check-in message.

% {uncheckout,unco,revert}

    Undo a checkout, reverting to checked-in version.

    -k(eep)     Retain the existing version in a '.keep' file.

% {remove,rm,delete,del}

    Mark an element as deleted.

GLOBAL OPTIONS

    -r          recurse into sub-directories
                (by default, operates locally)

    -t          test/dry-run/simulate mode
                don\'t actually do anything

    --debug     debug cleartool interaction

EOF

#---( Imports )---

require 'pathname'

#---( Globals )---

$cwd = Pathname.new('.').expand_path
$test_mode = false
$debug_mode = false

#---( Ignorance is bliss )---

$ignore_patterns = []

def ignore(regexp)
  $ignore_patterns << regexp
end

def ignored?(path)
  $ignore_patterns.each { |rexexp| return true if rexexp === path }
  return false
end

ignore %r{(^|/).temp}
ignore %r{(^|/)bin}
ignore %r{(^|/)classes}
ignore %r{/orbtrc}
ignore %r{\.LST$}
ignore %r{\.ant-targets-}
ignore %r{\.class$}
ignore %r{\.contrib$}
ignore %r{\.contrib\.\d+$}
ignore %r{\.iws$}
ignore %r{\.jar$}
ignore %r{\.jasper$}
ignore %r{\.keep$}
ignore %r{\.log$}
ignore %r{\.lst$}
ignore %r{\.merge$}
ignore %r{\.temp$}
ignore %r{\.tmp$}
ignore %r{\.unloaded$}
ignore %r{junit\d+\.properties$}
ignore %r{null}
ignore %r{~$}

#---( Utilities )---

def mkpath(path)
  Pathname.new(path.to_str.tr('\\', '/').sub(%r{^./},''))
end

def log_debug(msg)
  $stderr.puts(msg) if $debug_mode
end

#---( Output formatting )---

# Represents the status of an element
class ElementStatus

  def initialize(path, status, base_version = nil)
    @path = path
    @status = status
    @base_version = base_version
  end

  attr_reader :path, :status, :base_version

  def to_s
    s = "#{path} (#{status})"
    s += " [#{base_version}]" if base_version
    return s
  end

end

# Object responsible for nice fomatting of output
class DefaultListener

  def report(element)
    printf("%-7s %-15s %s\n", element.status, 
           element.base_version, element.path)
  end
  
end

#---( Target list )---

class TargetList

  include Enumerable

  def initialize(targets)
    @target_paths = targets.map { |t| mkpath(t) }
  end
  
  def each
    @target_paths.each do |t|
      yield(t)
    end
  end
  
  def to_s
    @target_paths.join(" ")
  end

  def empty?
    @target_paths.empty?
  end

  def parents
    TargetList.new(@target_paths.map { |t| t.parent }.uniq)
  end

end

#---( Commands )---

# Base ClearCase command
class Command

  attr_writer :listener
  attr_writer :targets

  def initialize()
    @listener = DefaultListener.new
    @recursive = false
    @graphical = false
  end

  def report(status, path, version = nil)
    @listener.report(ElementStatus.new(path, status, version))
  end

  def option_recurse
    @recursive = true
  end

  alias :option_r :option_recurse

  def option_graphical
    @graphical = true
  end

  alias :option_g :option_graphical

  # Handle command-line arguments:
  # - For option arguments of the form "-X", call the corresponding
  #   option_X() method.
  # - Remaining arguments are stored in @targets
  def accept_args(args)
    while /^-+(.+)/ === args[0]
      option = args.shift
      option_method = "option_#{$1}".to_sym
      unless respond_to?(option_method)
        raise "Unrecognised option: #{option}"
      end
      send(option_method)
    end
    @targets = args
    self
  end

  def effective_targets
    TargetList.new(@targets.empty? ? ['.'] : @targets)
  end

  def specified_targets
    raise "No target specified" if @targets.empty? 
    TargetList.new(@targets)
  end
  
  private

  def cleartool(command)
    log_debug "RUNNING: cleartool #{command}"
    IO.popen("cleartool " + command).each_line do |line|
      log_debug "<<< " + line
      yield(line) if block_given? 
    end
  end
    
  def cannot_deal_with(line)
    $stderr.puts "unrecognised output: " + line
  end

  def prompt_for_comment
    comment_file_path = Pathname.new("basketcase-comment.tmp")
    comment_file_path.open('w') do |comment_file|
      puts "Enter message (terminated by '.'):"
      $stdout.flush
      message = ""
      $stdin.each_line do |line|
        break if line.chomp == '.'
        comment_file << line
      end
    end
    return comment_file_path
  end

end

class LsCommand < Command

  def initialize()
    super
    @recurse_arg = '-r'
  end

  def option_all
    @include_all = true
  end

  alias :option_a :option_all

  def option_directory
    @directory_only = true
  end

  alias :option_d :option_directory

  def execute
    args = ''
    args += ' -recurse' if @recursive
    args += ' -directory' if @directory_only
    cleartool("ls #{args} #{effective_targets}") do |line|  
      case line
      when /^(\S+)@@(\S+) \[hijacked\]/
        report(:HIJACK, mkpath($1), $2)
      when /^(\S+)@@(\S+) \[loaded but missing\]/
        report(:MISSING, mkpath($1), $2)
      when /^(\S+)@@(\S+) +Rule: /
        next unless @include_all
        report(:OK, mkpath($1), $2)
      when /^(\S+)@@\S+ from (\S+)/
        element_path = mkpath($1)
        status = element_path.exist? ? :CO : :MISSING
        report(status, element_path, $2)
      when /^(\S+)/ 
        path = mkpath($1)
        next if ignored?(path)
        report(:LOCAL, path)
      else
        cannot_deal_with line
      end
    end
  end

end

class UpdateCommand < Command

  def option_nomerge
    @nomerge = true
  end

  def relative_path(s)
    raise '@root not defined' unless(@root)
    full_path = @root + mkpath(s)
    full_path.relative_path_from($cwd)
  end

  def execute_update 
    cleartool("pwv -root") do |line|
      @root = mkpath(line.chomp)
    end
    action = $test_mode ? '-print' : ''
    cleartool("update -log nul -force #{action} #{effective_targets}") do |line|
      case line
      when /^Processing dir "(.*)"/
        # ignore
      when /^\.*$/
        # ignore
      when /^Making dir "(.*)"/
        report(:NEW, relative_path($1))
      when /^Loading "(.*)"/
        report(:UPDATED, relative_path($1))
      when /^Unloaded "(.*)"/
        report(:REMOVED, relative_path($1))
      when /^Keeping hijacked object "(.*)" - base "(.*)"/
        report(:HIJACK, relative_path($1), $2)
      when /^End dir/
        # ignore
      when /^Done loading/
        # ignore
      else
        cannot_deal_with line
      end
    end
  end

  def execute_merge
    action = if $test_mode 
               "-print" 
             elsif @graphical
               "-gmerge"
             else
               "-merge -gmerge"
             end
    cleartool("findmerge #{effective_targets} -log nul -flatest #{action}") do |line|
      case line
      when /^Needs Merge "(.+)" \[to \S+ from (\S+) base (\S+)\]/
        report(:MERGE, mkpath($1), $2)
      end
    end
  end
  
  def execute
    execute_update
    execute_merge unless @nomerge
  end

end

class CheckinCommand < Command
  
  def execute
    puts "Checking-in:"
    specified_targets.each do |path|
      puts "  " + path
    end
    return if $test_mode
    comment_file = prompt_for_comment
    cleartool("checkin -cfile #{comment_file} #{specified_targets}") do |line|
      case line
      when /^Loading /
        # ignore
      when /^Making dir /
        # ignore
      when /^Checked in "(.+)" version "(\S+)"\./
        report(:COMMIT, mkpath($1), $2)
      else
        cannot_deal_with line
      end
    end
    comment_file.unlink
  end

end

class CheckoutCommand < Command
  
  def execute
    cleartool("checkout -unreserved -ncomment #{specified_targets}") do |line|
      case line
      when /^Checked out "(.+)" from version "(\S+)"\./
        report(:CO, mkpath($1), $2)
      when /^Element "(.+)" is already checked out/
        report(:CO, mkpath($1), 'already')
      end
    end
  end

end

class UncheckoutCommand < Command
  
  def initialize
    super
    @action = '-keep'
  end
  
  def option_rm
    @action = '-rm'
  end
  
  alias :option_r :option_rm

  def execute
    cleartool("uncheckout #{@action} #{specified_targets}") do |line|
      case line
      when /^Loading /
        # ignore
      when /^Making dir /
        # ignore
      when /^Checkout cancelled for "(.+)"\./
        report(:UNCO, mkpath($1))
      when /^Private version .* saved in "(.+)"\./
        report(:KEPT, mkpath($1))
      else
        cannot_deal_with line
      end
    end
  end

end

class CollectingListener

  attr_reader :elements

  def initialize
    @elements = []
  end

  def report(element)
    @elements << element
  end
  
end

class DirectoryModificationCommand < Command

  def find_locked_elements(paths)
    ls = LsCommand.new
    ls.option_a
    ls.option_d
    ls.targets = paths
    collector = CollectingListener.new
    ls.listener = collector
    ls.execute
    collector.elements.find_all { |e| e.status == :OK }.collect { |e| e.path }
  end

  def checkout(target_list)
    return if target_list.empty?
    co = CheckoutCommand.new
    co.targets = target_list
    co.execute
  end

  def unlock_parent_directories(target_list)
    checkout find_locked_elements(target_list.parents)
  end

end
  
class AutoCheckinCommand < Command

  def find_checkouts
    ls = LsCommand.new
    ls.option_a
    ls.targets = effective_targets
    collector = CollectingListener.new
    ls.listener = collector
    ls.execute
    collector.elements.find_all { |e| e.status == :CO }.collect { |e| e.path }
  end

  def execute
    checked_out_elements = find_checkouts
    if checked_out_elements.empty?
      puts "Nothing to check-in" 
      return
    end
    ci = CheckinCommand.new
    ci.targets = checked_out_elements
    ci.execute
  end
  
end

class RemoveCommand < DirectoryModificationCommand
  
  def execute
    unlock_parent_directories(specified_targets)
    cleartool("rmname -ncomment #{specified_targets}") do |line|
      case line
      when /^Unloaded /
        # ignore
      when /^Removed "(.+)"\./
        report(:RM, mkpath($1))
      else
        cannot_deal_with line
      end
    end
  end

end

class AddCommand < DirectoryModificationCommand
  
  def execute
    unlock_parent_directories(specified_targets)
    cleartool("mkelem -ncomment #{specified_targets}") do |line|
      case line
      when /^Created element /
        # ignore
      when /^Checked out "(.+)" from version "(\S+)"\./
        report(:ADDED, mkpath($1), $2)
      else
        cannot_deal_with line
      end
    end
  end

end

class DiffCommand < Command
  
  def execute
    args = ''
    args += ' -graphical' if @graphical
    @targets.each do |target|
      cleartool("diff #{args} #{target}@@\\main\\LATEST #{target}") do |line|
        puts line
      end
    end
  end

end

class LogCommand < Command
  
  def execute
    args = ''
    args += ' -graphical' if @graphical
    cleartool("lshistory #{args} #{effective_targets}") do |line|
      puts line
    end
  end
  
end

class VersionTreeCommand < Command
  
  def execute
    args = ''
    args += ' -graphical' if @graphical
    cleartool("lsvtree #{args} #{effective_targets}") do |line|
      puts line
    end
  end
  
end

#---( Command-line processing )---

class CommandLine

  def make_command(name)
    case name
    when 'list', 'ls', 'status', 'stat'
      LsCommand.new
    when 'update', 'up'
      UpdateCommand.new
    when 'checkout', 'co', 'edit'
      CheckoutCommand.new
    when 'checkin', 'ci', 'commit'
      CheckinCommand.new
    when 'uncheckout', 'unco', 'revert'
      UncheckoutCommand.new
    when 'remove', 'rm', 'delete', 'del'
      RemoveCommand.new
    when 'add'
      AddCommand.new
    when 'auto-checkin', 'auto-ci', 'auto-commit'
      AutoCheckinCommand.new
    when 'diff'
      DiffCommand.new
    when 'log', 'history'
      LogCommand.new
    when 'tree', 'vtree'
      VersionTreeCommand.new
    else
      raise "Unknown command: " + name
    end
  end

  def do(*args)

    # Handle global options (before the command)
    while /^-/ === args[0]
      option = args.shift
      case option
      when '-t'
        $test_mode = true
      when '--debug', '-d'
        $debug_mode = true
      else
        raise "Unrecognised global argument: #{option}"
      end
    end

    if args.empty?
      $stderr.puts $USAGE
      exit(1)
    end

    make_command(args.shift).accept_args(args).execute
    
  end

end

CommandLine.new.do(*ARGV)

# TODO:
# - mv/rename
# - addlocal
# - rmmissing
# - automatic uncheckout of removed elements
# - automatic uncheckout of files that can't be merged (for Durran)
