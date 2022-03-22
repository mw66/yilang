import std.stdio;

import visitor;


void print(Person p) {
  writeln("my only    name: " ~ p.name);
  writeln("my current addr: " ~ p.addr);
}

void print(Visitor p) {
  print(cast(Person)p);
  writeln("my UK addr: " ~ p.ukAddr);
  writeln("my US addr: " ~ p.usAddr);
}

void main() {
  Visitor v = newVisitor();
  v.name = "Yi";
  v.addr = "My hotel in Paris";
  v.ukAddr = "London";
  v.usAddr = "NewYork";

  Person p = v;

  print(p);  // will only print Person (i.e. the variable `p`'s type)
  print(v);
}
