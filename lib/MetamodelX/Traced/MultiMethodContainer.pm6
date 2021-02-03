use v6;
use Traced :TRACING;
use Traced::Routine :TRACING;
unit role MetamodelX::Traced::MultiMethodContainer;

method compose(Mu $obj is raw, |) {
    for self.multi_methods_to_incorporate: $obj -> Mu $multi is raw {
        TRACING Traced::Routine::Event, $multi, :multiness<multi>
            if Metamodel::Primitives.is_type($multi.code, Routine)
            && !$multi.code.?is-hidden-from-backtrace;
    }
    callsame
}
