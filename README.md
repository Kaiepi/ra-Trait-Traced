[![Build Status](https://travis-ci.com/Kaiepi/p6-Trait-Traced.svg?branch=master)](https://travis-ci.com/Kaiepi/p6-Trait-Traced)

NAME
====

Trait::Traced - Automagic tracing

SYNOPSIS
========

```perl6
use Trait::Traced;

# Oops! After some late night programming, we ended up with a buggy Power class,
# but we're having trouble finding the bug! No big deal; just slap an
# `is traced` on the class...
class Power is traced {
    has Numeric:D $.base     is required;
    has Numeric:D $.exponent is required;

    method new(::?CLASS:_: Numeric:D $base, Numeric:D $exponent --> ::?CLASS:D) {
        self.bless: :$base, :$exponent
    }

    multi method Numeric(::?CLASS:D: --> Numeric:D) {
        $!exponent ** $!base
    }
}

# ...and it will automatically get traced! With the output this generates, it's
# clear the bug's in the Numeric method:
my Power:D $two-cubed .= new: 2, 3;
quietly +$two-cubed; # OUTPUT:
# 1 [1 @ 1579397360.357204]
# <== [CALL] (Power) method new
#     self:      (Power)
#     $base:     2
#     $exponent: 3
#     *%_:       {}
# ==> Power.new(base => 2, exponent => 3)
#     2 [1 @ 1579397360.386552]
#     <== [CALL] (Power) multi method Numeric
#         self: Power.new(base => 2, exponent => 3)
#         *%_:  {}
#     ==> 9
# 3 [1 @ 1579397360.385728]
# <== [CALL] (Mu) proto method Numeric
#     self: Power.new(base => 2, exponent => 3)
#     |:    \()
# ==> 9
```

DESCRIPTION
===========

Trait::Traced is a library that provides the `is traced` trait, which allows anything a trait can be applied to to be traced. This is designed in such a way as to allow anyone to add custom tracing support of their own to this trait without needing to modify the library itself.

Documentation for its various features may be found at its [wiki](https://github.com/Kaiepi/p6-Trait-Traced/wiki).

AUTHOR
======

Ben Davies (Kaiepi)

COPYRIGHT AND LICENSE
=====================

Copyright 2020 Ben Davies

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

