use v6.d;
use Test;
use Tracer::Default;
use Trait::Traced;

sub trace(&run, &parse?) {
    my Str:D $filename = 'Trait-Traced-testing-' ~ 1_000_000.rand.floor ~ '.txt';
    my $*TRACER := Tracer::Default[$*TMPDIR.child($filename).open: :w];
    LEAVE {
        $*TRACER.handle.close;
        $*TRACER.handle.path.unlink;
    }
    run;
    $*TRACER.handle.flush;
    parse $*TRACER.handle.path.slurp(:close) with &parse;
}

plan 29;

# $Bar, @Baz, and %Qux get their symbols looked up outside of the tests, which
# gets traced to $*OUT without this.
PROCESS::<$TRACER> := Tracer::Default[$*OUT but role {
    method lock(|)   { }
    method unlock(|) { }
    method WRITE(|)  { 0 }
}];

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
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / <after '<== '> 'Foo::Foo' »  /,
      '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        $Foo::Bar
    }, 'can look up $ sigilled symbols...';
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / <after '<== '> '$Foo::Bar' »  /,
      '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        @Foo::Baz
    }, 'can look up @ sigilled symbols...';
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / <after '<== '> '@Foo::Baz' »  /,
      '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        %Foo::Qux
    }, 'can look up % sigilled symbols...';
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / <after '<== '> '%Foo::Qux' »  /,
      '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        &Foo::Quux
    }, 'can look up & sigilled symbols...';
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / <after '<== '> '&Foo::Quux' »  /,
      '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        my Int:D $foo = 5;
        Foo::<Foo> := Proxy.new:
            FETCH => sub FETCH($)             { $foo },
            STORE => sub STORE($, Int:D $bar) { $foo = $bar };
    }, 'can bind to symbols...';
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / « 'old: 0' $$ /,
      '...that includes the old value as an entry...';
    ok $output ~~ / « 'new: 5' $$ /,
      '...and likewise the new value';
};

trace {
    lives-ok {
        Foo::<$Bar> = 6;
    }, 'can assign to symbols...';
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / « 'old: 1' $$ /,
      '...that includes the old value as an entry...';
    ok $output ~~ / « 'new: 6' $$ /,
      '...and likewise the new value';
};

trace {
    lives-ok {
        Foo::<$*DYNAMIC>;
    }, 'can look up symbols with twigils...';
}, -> Str:D $output {
    ok $output, '...which produce output...';
    ok $output ~~ / <after '<== '> '$*Foo::DYNAMIC' »  /,
      '...that claims the lookup is for the correct symbol';
};

trace {
    lives-ok {
        Foo::<Foo> = 7;
    }, 'stash lookups/binds/assignments handle containers ok';
};

# Foo::Foo gets evaluated well before these tests actually runs.
trace {
    use MONKEY-SEE-NO-EVAL;
    EVAL Q[quietly Foo::Foo];
}, -> Str:D $output {
    ok $output, 'direct symbol lookups get traced...';
    ok $output ~~ / ^^ '==> 7' $$ /,
      '...and their output includes the correct result';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et
