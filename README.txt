= basketcase

BasketCase is a (Ruby) script that encapsulates the Rational ClearCase
command-line interface, <code>cleartool</code>, making it (slightly) more
comfortable for developers more used to non-locking version-control systems
such as CVS or Subversion.

== Features

BasketCase can help you:

* <strong>List</strong> modified elements.
* <strong>Update</strong> a snapshot view, including <strong>automatic merge</strong> of modified elements.
* <strong>Check-out</strong> (unreserved) and <strong>check-in</strong> elements.
* <strong>Undo a check-out</strong>, reverting to the base version.
* Perform a <strong>bulk check-in</strong> (or revert).
* <strong>Add</strong>, <strong>remove</strong> and <strong>rename</strong> elements.
* Display <strong>change-logs</strong> and <strong>version-trees</strong>.
* Display <strong>differences</strong> for modified elements.

== Synopsis

  usage: basketcase <command> [<options>]

  GLOBAL OPTIONS

      -t/--test   test/dry-run/simulate mode
                  (ie. don't actually do anything)

      -d/--debug  debug cleartool interaction

  COMMANDS        (type 'basketcase help <command>' for details)

      % list, ls, status, stat
      % lsco
      % diff
      % log, history
      % tree, vtree
      % update, up
      % checkin, ci, commit
      % checkout, co, edit
      % uncheckout, unco, revert
      % add
      % remove, rm, delete, del
      % move, mv, rename
      % auto-checkin, auto-ci, auto-commit
      % auto-uncheckout, auto-unco, auto-revert
      % auto-sync, auto-addrm
      % help

== Installation

Is as easy as:

  sudo gem install basketcase

== Background

In mid-2006, Mike Williams worked on a client project which, despite the
team's wishes, was burdened with ClearCase as it's source-code control
system.

The team was attempting to use Agile practices such as collective code
ownership, refactoring and continuous-integration, and ClearCase was in the
way:

* ClearCase enables and in many ways favours "reserved" check-outs of
  elements, preventing collective code ownership.
* When add, removing or moving elements, ClearCase will sometimes apply the
  change to the repository immediately, without waiting for a "commit".
* When updating, ClearCase will not attempt to merge other developers'
  changes to elements you have checked-out ... leaving your view in an
  inconsistent state.
* Performing an automatic merge from the command-line requires an unwieldy,
  obscure command.
* There is no easy way to do a bulk-commit from the command-line.

Mike wrote BasketCase in frustration.

== See also

* http://rubyforge.org/projects/basketcase/
* http://dogbiscuit.org/mdub/

== License

(The MIT License)

Copyright (c) 2008 Mike Williams

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
