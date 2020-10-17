import std.stdio;

import visitor;


void printPerson(Person p) {
  writeln("my only    name: " ~ p.name);
  writeln("my current addr: " ~ p.addr);
}

void printVisitor(Visitor p) {
  printPerson(p);
  writeln("my UK addr: " ~ p.ukAddr);
  writeln("my US addr: " ~ p.usAddr);
}

void main() {
  Visitor v = newVisitor();
  v.name = "Yi";
  v.addr = "My hotel in Paris";
  v.ukAddr = "London";
  v.usAddr = "NewYork";

  printVisitor(v);
}
