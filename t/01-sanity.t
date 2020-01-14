use v6.d;
use Test;
use Trait::Traced;

plan 2;

ok PROCESS::<$TRACER>:exists, 'the default tracer exists...';
cmp-ok PROCESS::<$TRACER>, &[===], $*OUT, '...and is stdout';
