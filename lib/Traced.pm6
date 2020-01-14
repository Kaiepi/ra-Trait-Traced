use v6.d;
#|[ A role done by classes that handle tracing for a type of object of some
    sort. ]
unit role Traced;

my atomicint $indent-level ⚛= -1;
#|[ Indents a line of a trace's output. ]
method !indent(::?CLASS:D: Str:D $line --> Str:D) {
    ' ' x 4 x ⚛$indent-level ~ $line
}
#|[ Bumps the indentation level by one while the given block is being run. ]
method !protect(::?CLASS:D: &block is raw --> Mu) is raw {
    $indent-level⚛++;
    LEAVE $indent-level⚛--;
    block
}

#|[ Wraps an object to make it traceable somehow. ]
proto method wrap(::?CLASS:U: | --> Mu) {*}

#|[ Performs a trace, which is output to $*TRACER somehow. ]
proto method trace(::?CLASS:D: --> Mu) is raw {
    self!protect: {{*}}
}
