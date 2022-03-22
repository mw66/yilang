import std.stdio;

import visitor;


void print(Person p) {
  writeln("my only    name: " ~ p.name);
  writeln("my current addr: " ~ p.addr);
}

void print(Visitor v) {
  Person p = v;
  print(p);
  writeln("my UK addr: " ~ v.ukAddr);
  writeln("my US addr: " ~ v.usAddr);
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
