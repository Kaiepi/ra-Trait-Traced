use v6;
use Traced::Routine;
unit role MetamodelX::Traced::MethodContainer;

method compose(::?CLASS:D: Mu $package is raw, | --> Mu) {
    for self.methods: $package, :local -> Mu $method is raw {
        Traced::Routine.wrap: $method, multiness => $method.is_dispatcher ?? 'proto' !! ''
            if Metamodel::Primitives.is_type($method, Routine)
            && !$method.?is-hidden-from-backtrace;
    }
    callsame
}
