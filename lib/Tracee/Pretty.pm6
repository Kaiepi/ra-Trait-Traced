use v6;
use Traced;
use Traced::Attribute;
use Traced::Routine;
use Traced::Stash;
use Traced::Variable;
use Tracee::Standard;
#|[ A tracee that produces standard, human-readable output. ]
unit class Tracee::Pretty does Tracee::Standard is repr<Uninstantiable>;

#|[ Prettifies a traced value. ]
our proto sub prettify(Mu --> Str:D)                            {*}
    multi sub prettify(Mu $value is raw --> Str:D)              { $value.gist }
    multi sub prettify(Exception:D $exception is raw --> Str:D) { "\e[31m$exception.^name()\e[m" }
    multi sub prettify(Failure:D $failure is raw --> Str:D)     { "\e[33m$failure.exception.^name()\e[m" }
    multi sub prettify(Junction:D $junction is raw --> Str:D)   { $junction.THREAD(&prettify).gist }

#|[ Transforms a traced event to the standard format. ]
method fill(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL --> Str:D) {
    my Str:D $margin := ' ' x 4 * $e.calls;
    self.title($e, :$nl, :$margin) ~
    self.header($e, :$nl, :$margin) ~
    self.entries($e, :$nl, :$margin).join ~
    self.footer($e, :$nl, :$margin)
}

#|[ A trace's title. This contains metadata that distinguishes traces from one another. ]
proto method title(::?CLASS:U: Traced:D $e is raw;; Str:D :$nl is raw = $?NL, Str:D :$margin! is raw --> Str:D) {
    "$margin    \e[;1m$e.id() {{*}}$e.kind() $e.of()\e[;2m [$e.thread-id() @ $e.timestamp.fmt(<%f>)]$nl"
}
multi method title(::?CLASS:U: Traced::Routine::Event --> "\e[2;31m")   { }
multi method title(::?CLASS:U: Traced::Stash::Event --> "\e[2;32m")     { }
multi method title(::?CLASS:U: Traced::Variable::Event --> "\e[2;33m")  { }
multi method title(::?CLASS:U: Traced::Attribute::Event --> "\e[2;34m") { }

#|[ A trace's header. This represents an input of some sort. ]
proto method header(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw --> Str:D) {
    "$margin\<== \e[;1m{{*}}$nl"
}
multi method header(::?CLASS:U: Traced::Routine::Event $e is raw --> Str:D) {
    "$e.declarator() \e[2m($e.package.^name())\e[m"
}
multi method header(::?CLASS:U: Traced::Stash::Event $e is raw --> Str:D) {
    $e.longname
}
multi method header(::?CLASS:U: Traced::Variable::Event $e is raw --> Str:D) {
    "$e.declarator() \e[2m($e.package.^name())\e[m"
}
multi method header(::?CLASS:U: Traced::Attribute::Event $e is raw --> Str:D) {
    "$e.declarator() \e[2m($e.package.^name())\e[m"
}

#|[ A trace's entries. This represents arguments of some sort given alongside an input. ]
proto method entries(::?CLASS:U: Traced:D --> Seq:D) {*}
multi method entries(::?CLASS:U: Traced:D --> Seq:D) { Empty.Seq }
multi method entries(::?CLASS:U:
    Traced::Routine::Event:D $e is raw;; Str:D :$nl is raw = $?NL, Str:D :$margin! is raw
--> Seq:D) {
    gather for $e -> Pair:D $argument is raw {
        my Parameter:D $p := $argument.key;
        my Mu          $a := $argument.value;
        once take-rw (self => $a) and next if $p.invocant and not $p.name;
        take-rw ("$p.prefix()$p.sigil()$p.twigil()$p.usage-name()" => $a);
    } ==> my Pair:D @entries;

    gather for @entries -> Pair:D $entry is raw {
        state Int:D $width    = @entries.map(*.key.chars).max;
        state Str:D $extra    = ' ' x $width + 2;
        my    Str:D $key     := $entry.key;
        my    Mu    $value   := $entry.value;
        my    Str:D $padding := ' ' x $width - $key.chars;
        take-rw "$margin    \e[1m$key\e[m:$padding $value.&prettify.subst($nl, qq/$nl$margin    $extra/, :g)$nl";
    }
}
multi method entries(::?CLASS:U:
    Traced::Stash::Event:D $e is raw;; Str:D :$nl is raw = $?NL, Str:D :$margin! is raw
--> Seq:D) {
    gather if $e.modified {
        take-rw "$margin    $e.value.&prettify.subst($nl, qq/$nl$margin         /, :g)$nl";
    }
}

#|[ A trace's footers. This represents an output of some sort. ]
method footer(::?CLASS:U: Traced:D $e is raw, Str:D :$nl is raw = $?NL, Str:D :$margin! is raw--> Str:D) {
    $e.died
        ?? "$margin\e[;2m!!!\e[m $e.exception.&prettify.subst($nl, qq/$nl$margin    /, :g)$nl"
        !! "$margin\e[;2m==>\e[m $e.result.&prettify.subst($nl, qq/$nl$margin    /, :g)$nl"
}
