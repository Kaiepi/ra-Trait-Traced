use v6.d;
use Trait::Traced;
use Test;

plan 2;

ok PROCESS::<$TRACER>:exists, 'the default tracer exists...';
cmp-ok $*TRACER.handle, '===', $*OUT, '...which is stdout';

# vim: ft=perl6 sw=4 ts=4 sts=4 et
