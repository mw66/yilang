balance between freedom and discipline

-- Lisp (CLOS), the programmer has freedom
-- C++/Java/Eiffel: discipline

each YI class is compiled into
-- a D interface (with accessor func only) NOTE: this is wrong! this will rely on D-interface multiple inheritance behavior!
-- a D class with attr, and accessor func implementation only

all other methods are multi-method defined outside of any classes

We should really just use D just as better C.

# PEG grammar for Python
https://docs.python.org/3/reference/grammar.html

attributes:

```
struct Student {
  string name;
  string addr;
}

struct Teacher {
  string name;
  int    age;
  string addr;
}


struct TA {
  // no matter which slot we put addr, we can NOT pass a TA* pointer
  // to a Teacher* (expect 3rd slot as addr), or Student* (expect 2nd slot as addr)
  // therefore, attributes are not inherited!

  // each class has its own data layout, and *ALL* methods are virtual!
  // esp. each class's getter() / setter() methods, which access the correct slot of each class
}
```

Even in C++ MI memory model, for shared attributes, the compiler need to rearrange the struct layout,
it cannot plainly tile the super-class' struct piece by piece.


Only need to introduce one keyword `rename` (mainly because of fields to rearrange memory layout),
and we do not even need to use `override` since it can be detected by the compiler.

get rid of `undefine/select`

The purpose of `undefine` is not to make the subclass abstract, but feature adaptation.
Better solution for feature adaptation, if a subclass has multiple super-class with function of the same name:
-- the programmer has to provide one resolution:
-- auto rename, i.e. prefixed by super-class name, so we can get rid of the `rename` keywords
-- redefine i.e. override to provide a new implementation, by:
  -- combine the super-classes' functions, by using the fully function name
  -- or `select` one super-class' function as a short-cut, but shall we add `select` keyword only for this purpose?

for fields, either join or separate:
-- default is join, so the sub-class only have one such field (in memory layout)
-- or use `rename` to separate, so the sub-class can have multiple renamed fields (in memory layout)


# Python criticism
Not compiled, many errors that can be prevented during compile time only show up until very late run time.

# Eiffel criticism
export status adaptation

https://archive.eiffel.com/doc/online/eiffel50/intro/language/tutorial-10.html
section: Changing the export status

```
class Super
  {ANY} feature_x

class Sub inherit Super
  export {NONE} feature_x
```

The problems are:
1. all the client of Super are promised to access `super.feature_x`, but when the client has an instance of Sub,
   they no longer able to access it, `sub.feature_x`. This break the contract, since the Sub is-a Super.
```
  sub:Sub := Sub.make
  sub.feature_x  -- error: the client can access sub.feature_x
```

2. actually, the client can still acccess it by using a Super variable to hold the Sub instance, i.e.
```
  super:Super := sub  -- assign to a variable of type Super
  super.feature_x  -- now the client can effectively access sub.feature_x
```
   This can be considered as a loophole in the eport status adaptation.

http://se.ethz.ch/~meyer/publications/online/eiffel/basic.html
Non-conforming inheritance:
Sometimes inheritance is for reuse only and is not intended for polymorphism.

http://se.ethz.ch/~meyer/publications/online/eiffel/basic.html
Uniform Access Principle: from the outside, whether a query is an attribute (field in each object) or a function (algorithm) should not make any difference. For example a_vehicle.speed could be an attribute, accessed from the object's representation; or it could be computed by a function that divides distance by time. The notation is the same in both cases, so that it's easy to change representation without affecting the rest of the software.


However, field and function have different adaptation policies: e.g. field cannot be undefined.

