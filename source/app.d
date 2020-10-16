import std.exception;
import std.file;
import std.stdio;

import boilerplate;
import commandr;
import pegged.grammar;

import yigrammar;


mixin(grammar(yigrammar.YiGrammar));


class Field {
  string type;
  string name;

  mixin(GenerateToString);
}

class ClassDeclaration {
  string name;
  SuperClass[] superClass;
  Field[] fields;
}

class ClassAdapter {
}

class SuperClass {
  string name;
  ClassAdapter[] classAdapters;
}

class Rename : ClassAdapter {
  string oldName;
  string newName;
  mixin(GenerateToString);
}


class System {
  ClassDeclaration[] classDeclarations;

  void summary() {
    foreach (c; classDeclarations) {
      writeln(c.name);
    }
  }
}


// input Yi code, output D code
string compile(ProgramArgs pargs, string yiFn) {

  auto system = new System();

  string yicode = std.file.readText(yiFn);
  auto p = Yi(yicode);
  // writeln(p, p.matches);  // useful for debug

  void visitSuperClass(ParseTree p, SuperClass s) {
    switch (p.name) {
    case "Yi.ClassAdapters":
    case "Yi.ClassAdapter":
      foreach(i, child; p.children) {
        visitSuperClass(child, s);
      }
      return;
    case "Yi.Rename":
      /*
      foreach(i, child; p.children) {
        writeln(i, child);
      }
      */
      auto r = new Rename();
      r.oldName = p.children[0].matches[0];
      r.newName = p.children[1].matches[0];
      s.classAdapters ~= r;
      return;
    default:
      enforce(false, "shouldn't reach here: " ~ p.name);
    }
  }

  void visitClassDeclaration(ParseTree p, ClassDeclaration c) {
    switch (p.name) {
    case "Yi.SuperClass":
      auto s = new SuperClass();
      s.name = p.children[0].matches[0];
      foreach (child; p.children[1..$]) {
        visitSuperClass(child, s);
      }
      writeln(s.name, s.classAdapters);
      c.superClass ~= s;
      return;
    case "Yi.Field":
      auto f = new Field();
      f.type = p.children[0].matches[0];
      f.name = p.children[1].matches[0];
      c.fields ~= f;
      return;
    default:
      foreach (i, child; p.children) {
        visitClassDeclaration(child, c);
      }
      // enforce(false, "shouldn't reach here: " ~ p.name);
    }
  }

  // output D code
  string visit(ParseTree p) {
    switch (p.name) {
    case "Yi.ClassDeclaration":
      auto c = new ClassDeclaration();
      c.name = p.children[0].matches[0];
      foreach (child; p.children[1..$]) {
        visitClassDeclaration(child, c);
      }
      writeln(c.name, c.superClass, c.fields);
      system.classDeclarations ~= c;
      return "c";
    default:
      writeln(p.name);
      foreach (i, child; p.children) {
        visit(child);
      }
      //return p.name;
    }
    return "";
  }


  string dcode = visit(p);  // pass the tree root

  // whole system semantic check for all the class, and generate code
  system.summary();

  return dcode;
}

void main(string[] args) {
  auto pargs = new Program("yc", "0.0.1")
          .summary("Yi compiler")
          .author("<admin@yilabs.com>")
          .add(new Flag("v", null, "turns on more verbose output")
              .name("verbose")
              .repeating)
          .add(new Option("c", "RUNCFG", "").validateEachWith(opt => opt.isFile, "must be a valid file"))
          .parse(args);

  string yiFn = pargs.option("RUNCFG");

  compile(pargs, yiFn);
}
