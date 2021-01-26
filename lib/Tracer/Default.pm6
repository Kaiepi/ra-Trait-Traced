use v6;
use Tracee::Bitty;
use Tracee::Pretty;
use Tracer::File;
use Tracer::Stream;
unit class Tracer::Default;

#|[ Returns the handle the tracer was parameterized with. ]
method handle(::?CLASS:_: --> IO::Handle:D) { ... }

role TTY does Tracer::Stream[Tracee::Pretty] { }

role File does Tracer::File[Tracee::Bitty] { }

method ^parameterize(::?CLASS:U $this is raw, IO::Handle:D $handle is raw --> ::?CLASS:D) {
    my Mu         $mixin  := $handle.t ?? TTY !! File;
    my ::?CLASS:D $tracer := $this.new does $mixin :value($handle);
    $tracer.^set_name: self.name($this) ~ qq/["$handle"]/;
    $tracer
}
