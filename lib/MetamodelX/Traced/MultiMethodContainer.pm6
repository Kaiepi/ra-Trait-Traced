use v6.d;
use Traced::Routine;
unit role MetamodelX::Traced::MultiMethodContainer;

method compose(Mu $obj is raw, |) {
    for self.multi_methods_to_incorporate: $obj -> Mu $multi is raw {
        Traced::Routine.wrap: $multi, :multi
            if Metamodel::Primitives.is_type($multi.code, Routine)
            && !$multi.code.?is-hidden-from-backtrace;
    }
    callsame
}
