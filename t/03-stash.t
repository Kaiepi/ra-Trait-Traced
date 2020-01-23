use v6.d;
use Test;
use Trait::Traced;

plan 27;

sub wrap-tests(&block is raw --> Mu) is raw {
    my Str:D      $filename  = 'Trait-Traced-testing-' ~ 1000000.rand.floor ~ '.txt';
    my IO::Pipe:D $*TRACER  := $*TMPDIR.child($filename).IO.open: :w;
    LEAVE {
        $*TRACER.close;
        $*TRACER.path.unlink;
    }
    block
}

# $Bar, @Baz, and %Qux get their symbols looked up once Foo's body block gets
# called at runtime, which gets traced to $*OUT without this.
$GLOBAL::TRACER = ($*DISTRO.is-win ?? 'NUL' !! '/dev/null').IO.open: :w;
LEAVE $*TRACER.close;

my module Foo is traced {
    constant Foo = 0;
    our $Bar = 1;
    our @Baz = 2,;
    our %Qux = :3a;
    our sub Quux { 4 }
    our $*DYNAMIC;
}

wrap-tests {
    lives-ok {
        Foo::<Foo>
    }, 'can look up sigilless symbols...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / <after '] '> 'Foo::Foo' $$ /,
      '...that claims the lookup is for the correct symbol';
};

wrap-tests {
    lives-ok {
        $Foo::Bar
    }, 'can look up $ sigilled symbols...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / <after '] '> '$Foo::Bar' $$ /,
      '...that claims the lookup is for the correct symbol';
};

wrap-tests {
    lives-ok {
        @Foo::Baz
    }, 'can look up @ sigilled symbols...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / <after '] '> '@Foo::Baz' $$ /,
      '...that claims the lookup is for the correct symbol';
};

wrap-tests {
    lives-ok {
        %Foo::Qux
    }, 'can look up % sigilled symbols...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / <after '] '> '%Foo::Qux' $$ /,
      '...that claims the lookup is for the correct symbol';
};

wrap-tests {
    lives-ok {
        &Foo::Quux
    }, 'can look up & sigilled symbols...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / <after '] '> '&Foo::Quux' $$ /,
      '...that claims the lookup is for the correct symbol';
};

wrap-tests {
    lives-ok {
        my Int:D $foo = 5;
        Foo::<Foo> := Proxy.new:
            FETCH => sub FETCH($)             { $foo },
            STORE => sub STORE($, Int:D $bar) { $foo = $bar };
    }, 'can bind to symbols...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / « 'old: 0' $$ /,
      '...that includes the old value as an entry...';
    ok $result ~~ / « 'new: 5' $$ /,
      '...and likewise the new value';
};

wrap-tests {
    lives-ok {
        Foo::<$Bar> = 6;
    }, 'can assign to symbols...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / « 'old: 1' $$ /,
      '...that includes the old value as an entry...';
    ok $result ~~ / « 'new: 6' $$ /,
      '...and likewise the new value';
};

wrap-tests {
    lives-ok {
        Foo::<$*DYNAMIC>;
    }, 'can look up symbols with twigils...';
    $*TRACER.flush;
    ok my Str:D $result = $*TRACER.path.slurp(:close),
      '...which produces output...';
    ok $result ~~ / '$*Foo::DYNAMIC' /,
      '...that claims the lookup is for the correct symbol';
};

wrap-tests {
    lives-ok {
        Foo::<Foo> = 7;
    }, 'stash lookup/binding/assignment handles containers ok';
};

# vim: ft=perl6 sw=4 ts=4 sts=4 et
