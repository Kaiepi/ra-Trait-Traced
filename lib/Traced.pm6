use v6.d;
#|[ A role done by classes that handle tracing for a type of event. ]
unit role Traced;

#|[ The instant the trace was taken at. ]
has Instant:D $.moment is required;

#|[ Wraps an object of this trace's event type to make it traceable somehow. ]
proto method wrap(::?CLASS:U: | --> Mu) {*}

BEGIN my $THREAD-INDENT-LEVELS = %();
sub increment-indent-level(%indent) {
    my Int:D $id = $*THREAD.id;
    if %indent{$id}:exists {
        %indent{$id}++;
    } else {
        %indent{$id} = 0;
    }
    %indent
}
sub decrement-indent-level(%indent) {
    my Int:D $id = $*THREAD.id;
    if %indent{$id}:exists {
        %indent{$id}--;
    } else {
        %indent{$id} = 0;
    }
    %indent
}
#|[ Bumps the indentation level of a trace while executing the given block. ]
method !protect(::?CLASS:_: &block is raw --> Mu) is raw {
    cas $THREAD-INDENT-LEVELS, &increment-indent-level;
    LEAVE cas $THREAD-INDENT-LEVELS, &decrement-indent-level;
    block
}
#|[ Given a line of trace output, indents and returns it. ]
method !indent(::?CLASS:_: Str:D $line --> Str:D) {
    my Int:D $level = (⚛$THREAD-INDENT-LEVELS){$*THREAD.id};
    ' ' x 4 * $level ~ $line
}

#|[ The colour to use for the key of the trace's output. ]
method colour(::?CLASS:_: --> Int:D) { ... }
#|[ The key of the trace's output. ]
method key(::?CLASS:_: --> Str:D)    { ... }

#|[ Whether or not the event traced succeeded. ]
method success(::?CLASS:D: --> Bool:D) { ... }

#|[ Produces the header of the trace's output. ]
proto method header(::?CLASS:D: --> Str:D) {
    $*TRACER.t
        ?? sprintf("<== \e[%s;1m[%s]\e[0m \e[1m%s\e[0m [%s @ %s]",
                   $.colour, $.key, {*}, $*THREAD.id, $!moment.Rat)
        !! sprintf("<== [%s] %s [%s @ %s]",
                   $.key, {*}, $*THREAD.id, $!moment.Rat)
}

#|[ Produces the entries of the trace's output, if any. ]
proto method entries(::?CLASS:D: --> Seq:D) {
    my Pair:D @entries = {*} ==> map({
        state Str:D $format  = $*TRACER.t ?? "\e[1m%s\e[0m:%s %s" !! "%s:%s %s";
        state Int:D $width   = @entries.map(*.key.chars).max;
        my    Str:D $padding = ' ' x $width - .key.chars;
        sprintf $format, .key, $padding, .value
    })
}
multi method entries(::?CLASS:D: --> Seq:D) { ().Seq }

#|[ Produces the footer of the trace's output. ]
proto method footer(::?CLASS:D: --> Str:D) {
    my Str:D $prefix = $.success ?? '==>' !! '!!!';
    $*TRACER.t
        ?? sprintf("%s \e[1m%s\e[0m", $prefix, {*})
        !! sprintf("%s %s", $prefix, {*})
}

multi method lines(::?CLASS:D: --> Seq:D) {
    gather {
        take $.header;
        take ' ' x 4 ~ $_ for @.entries;
        take $.footer;
    }
}

multi method Str(::?CLASS:D: --> Str:D) {
    @.lines
==> map({ self!indent: $_ })
==> join($?NL)
}
