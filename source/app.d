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
  SuperClass[] superClass;  // this won't changed, after parsed
  Field[string] fields;     // directly from the source code

  mixin(GenerateToString);

  bool fieldsFlattened;
  Field[string] actualFields;  // after semanCheck, and consolidation with superClass' fields, all flattened
  // TODO: provide shallowClone() for each generated D class

  bool allSuperClassFieldsFlattened() {
    foreach (s; this.superClass) {
      if (!s.clazz.fieldsFlattened) {
        return false;
      }
    }
    return true;
  }

  // only check direct superClass
  void semanCheck() {
    writeln("semanCheck " ~ this.name);
    enforce(fieldsFlattened == false);

    enforce(allSuperClassFieldsFlattened());
    foreach (s; this.superClass) {
      enforce(s.clazz.fieldsFlattened);
      auto af = s.clazz.actualFields.dup;
      foreach (ca; s.classAdapters) {
        Field newField = ca.process(af[ca.orgName]);
        af[ca.orgName] = newField;
      }
      // same name here is joined
      foreach (f; af.values()) {
        actualFields[f.name] = f;
      }
    }

    // now add own fields
    foreach (f; fields.values()) {
      enforce(f.name !in actualFields, this.name ~ "'s super class has defined " ~ f.toString() ~ " already!");
      actualFields[f.name] = f;
    }

    fieldsFlattened = true;
    enforce(actualFields.length >= fields.length);
  }
}

class ClassAdapter {
  string orgName;
  abstract Field process(Field old);  // return new
}

class SuperClass {
  string name;
  ClassAdapter[] classAdapters;

  ClassDeclaration clazz;  // the class object after linked
}

class Rename : ClassAdapter {
  string newName;
  mixin(GenerateToString);

  override Field process(Field old) {  // return new
    enforce(old.name == orgName);
    Field newField = new Field();
    newField.type = old.type;
    newField.name = newName;
    return newField;
  }
}


class System {
  ClassDeclaration[string] classDeclarations;  // dict by class name

  // whole system semantic check for all the class, and generate code
  void semanCheck() {
    // 1) build class inheritance lattice, this lattice will also be the basis of runtime multiple dispatch
    foreach (c; classDeclarations.values()) {
      foreach (s; c.superClass) {
        enforce(s.name in classDeclarations, c.name ~ "'s superClass " ~ s.name ~ " not found!");
        s.clazz = classDeclarations[s.name];  // link to super class object
      }
    }

    // 2) calc each class fields from the top to bottom of the lattice
    bool processedOne = false;
    do {
      processedOne = false;
      foreach (c; classDeclarations.values()) {
        if (c.allSuperClassFieldsFlattened() && !c.fieldsFlattened) {
          c.semanCheck();
          processedOne = true;
        }
      }
    } while (processedOne);

    // 3) generate D code: interface, and implementation, and runtime dispatch table
    /* for each Yi class A, will generate:
       -- interface A : (multiple inherent other interface) {
            // no field def, since field not allowed in interface (see test/i.d)
            // only accessor method proto, e.g:
            @property ref int field();
          }

       -- class A_ : A (single A) {
            // the actual fields
            private int field_;

            // the accessor method implementation
            @property ref int field() {
              return field_;
            }
          }

       -- for fields reuse: the ClassAdapter are actually only change the accessor method
       -- for code reuse: use the multi-method, which access the implementation class' field via `ref type field`
       check testdata/ref.d

       usage:
       -- A a = new A_();
     */
  }

  void summary() {
    foreach (c; classDeclarations.values()) {
      writeln(c);
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
      r.orgName = p.children[0].matches[0];
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
      c.fields[f.name] = f;
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
      enforce(c.name !in system.classDeclarations, "duplicate defined class: " ~ c.name);
      system.classDeclarations[c.name] = c;
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
  system.semanCheck();
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
