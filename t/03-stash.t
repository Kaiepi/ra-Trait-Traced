use v6;
use lib $?FILE.IO.sibling: 'lib';
use Tracee::Bitty;
use Tracer::Stream;
use Trait::Traced;
use Test;
use Test::Trait::Traced;

# $Bar, @Baz, and %Qux get their symbols looked up outside of the tests, which
# gets traced to $*OUT without this.
PROCESS::<$TRACER> := Tracer::Stream[Tracee::Bitty].new: $*OUT but role {
    method lock(| --> True)   { }
    method unlock(| --> True) { }
    method WRITE(| --> 0)     { }
};

plan 28;

my module Foo is traced {
    constant Foo = 0;
    our $Bar = 1;
    our @Baz = 2,;
    our %Qux = :3a;
    our sub Quux { 4 }
    our $*DYNAMIC;
}

trace {
    lives-ok {
        Foo::<Foo>
    }, 'can look up sigilless symbols...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, 'Foo::Foo',
        '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        $Foo::Bar
    }, 'can look up $ sigilled symbols...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, '$Foo::Bar',
        '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        @Foo::Baz
    }, 'can look up @ sigilled symbols...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, '@Foo::Baz',
        '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        %Foo::Qux
    }, 'can look up % sigilled symbols...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, '%Foo::Qux',
        '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        &Foo::Quux
    }, 'can look up & sigilled symbols...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, '&Foo::Quux',
        '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        my Int:D $foo = 5;
        Foo::<Foo> := Proxy.new:
            FETCH => sub FETCH($)             { $foo },
            STORE => sub STORE($, Int:D $bar) { $foo += $bar };
    }, 'can bind to symbols...';
}, {
    ok $^output, '...which produce output...';
    has-entry $^output, '5', '...which contains a value...';
    has-footer $^output, '5', '...and a result';
};

trace {
    lives-ok {
        Foo::<Foo> = 5;
    }, 'can assign to symbols...';
}, {
    ok $^output, '...which produce output...';
    has-entry $^output, '5', '...that contains a value...';
    has-footer $^output, '10', '...and any differing result';
};

trace {
    lives-ok {
        Foo::<$*DYNAMIC>;
    }, 'can look up symbols with twigils...';
}, {
    ok $^output, '...which produce output...';
    has-header $^output, '$*Foo::DYNAMIC',
        '...that claims the lookup is for the correct symbol';
};

# Foo::Foo gets evaluated well before these tests actually runs.
trace {
    use MONKEY-SEE-NO-EVAL;
    EVAL Q[quietly Foo::Foo];
}, {
    ok $^output, 'direct symbol lookups get traced...';
    has-footer $^output, '10',
        '...and their output includes the correct result';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et
