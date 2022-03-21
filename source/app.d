import std.algorithm;
import std.array;
import std.exception;
import std.file;
import std.format;
import std.range;
import std.stdio;

import boilerplate;
import commandr;
import pegged.grammar;

import yigrammar;


mixin(grammar(yigrammar.YiGrammar));

immutable string DOT_YI = ".yi";
immutable string DOT_D  = ".d";

class Field {
  string type;
  string name;

  mixin(GenerateToString);

  bool newActualFields;  // renamed from superClass, or newly introduced in this class

  // we clone to process this Field in the derived class, hence set clone.newActualFields = false
  Field clone() {
    Field clone = new Field();
    clone.type = this.type;
    clone.name = this.name;
    clone.newActualFields = false;
    return clone;
  }

  /* return:
    @property ref int field()"
   */
  string toInterfaceCode() {
    return format("  @property ref %s %s()", type, name);
  }

  /* return:
    private int field_;"
    @property ref int field() {return field_;}
  */
  string toClassCode() {
    return ["  private " ~ type ~" "~ name ~ "_;",
        toInterfaceCode() ~ format(" {return %s_;}", name)].join("\n");
  }
}

class ClassDeclaration {
  string name;
  SuperClass[] superClass;  // this won't changed, after parsed; keep the original order in source code
  Field[string] fields;     // directly from the source code

  mixin(GenerateToString);

  int latticeOrder;  // in the inheritance lattice
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
    enforce(actualFields.length == 0);

    enforce(allSuperClassFieldsFlattened());
    foreach (s; this.superClass) {
      enforce(s.clazz.fieldsFlattened);
      typeof(s.clazz.actualFields) af;
      foreach (k, f; s.clazz.actualFields) {
        af[k] = f.clone();  // first clone
      }
      foreach (ca; s.classAdapters) {  // process in the same original order as in the source code
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
      f.newActualFields = true;
      enforce(f.name !in actualFields, this.name ~ "'s super class has defined " ~ f.toString() ~ " already!");
      actualFields[f.name] = f;
    }

    fieldsFlattened = true;
    enforce(actualFields.length >= fields.length);
  }

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
     -- "A newA() {return new A_();}"  shortcut func provided
   */
  string generateCode() {
    auto sortedFields = this.actualFields.values().sort!("a.name < b.name");

    // output only new fields in the interface
    string superClassCode = "";
    if (this.superClass.length > 0) {
      superClassCode = ": " ~ this.superClass.map!(s => s.name).join(", ");
    }
    string interfaceCode = chain(["interface " ~ this.name ~ superClassCode ~ " {"],
        sortedFields.filter!(f => f.newActualFields).map!(f => f.toInterfaceCode()~";").array,
        ["}"]).join("\n");

    // output all (old + new) the fields in the class
    string classCode = chain(["class " ~this.name~ "_ : " ~this.name~ " {"],
        sortedFields.map!(f => f.toClassCode()).array,
        ["}"]).join("\n");

    // "A newA() {return new A_();}"
    string newFuncCode = format("%s new%s() {return new %s_();}", this.name, this.name, this.name);

    string result = [interfaceCode, classCode, newFuncCode, ""].join("\n\n");
    // writeln(result);

    return result;
  }
}

class ClassAdapter {
  string orgName;
  abstract Field process(Field old);  // return new
}

class SuperClass {
  string name;
  ClassAdapter[] classAdapters;  // keep the original order in source code

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
    newField.newActualFields = true;
    return newField;
  }
}


class System {
  ClassDeclaration[string] classDeclarations;  // dict by class name
  ClassDeclaration[] sortedClassDeclarations;  // by c.latticeOrder

  // whole system semantic check for all the class, and generate code
  string semanCheck() {
    // 1) build class inheritance lattice, this lattice will also be the basis of runtime multiple dispatch
    foreach (c; classDeclarations.values()) {
      foreach (s; c.superClass) {
        enforce(s.name in classDeclarations, c.name ~ "'s superClass " ~ s.name ~ " not found!");
        s.clazz = classDeclarations[s.name];  // link to super class object
      }
    }

    // 2) calc each class fields from the top to bottom of the lattice
    int processedCount = 0, oldProcessedCount = 0;
    do {
      oldProcessedCount = processedCount;
      foreach (c; classDeclarations.values()) {
        if (c.allSuperClassFieldsFlattened() && !c.fieldsFlattened) {
          c.semanCheck();
          c.latticeOrder = processedCount++;
	  sortedClassDeclarations ~= c;
        }
      }
    } while (oldProcessedCount < processedCount && processedCount < classDeclarations.length);
    enforce(classDeclarations.length == processedCount);
    enforce(classDeclarations.length == sortedClassDeclarations.length);

    // 3) generate D code: interface, and implementation, and runtime dispatch table
    string allCode = sortedClassDeclarations.map!(c => c.generateCode()).join("\n");
    // writeln(allCode);
    return allCode;
  }

  void summary() {
    foreach (c; classDeclarations.values()) {
      // writeln(c);
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
  void visit(ParseTree p) {
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
      return;
    default:
      writeln(p.name);
      foreach (i, child; p.children) {
        visit(child);
      }
    }
  }


  visit(p);  // pass the tree root

  // whole system semantic check for all the class, and generate code
  string dcode = system.semanCheck();
  system.summary();

  string dFn = yiFn[0..$-DOT_YI.length] ~ DOT_D;
  std.file.write(dFn, dcode);

  return dcode;
}

int main(string[] args) {
  auto program = new Program("yc", "0.0.1");
  if (args.length <= 1) {
    program.printHelp();
    return 0;
  }

  auto pargs = program.summary("Yi compiler").author("<admin@yilabs.com>")
          .add(new commandr.Flag("v", null, "turns on more verbose output")
              .name("verbose")
              .repeating)
          .add(new Option("c", "YISRC", "").validateEachWith(opt => opt.isFile, "must be a valid file"))
          .parse(args);

  string yiFn = pargs.option("YISRC");
  if (!yiFn.endsWith(DOT_YI)) {
    writeln("invalid input filename: " ~ yiFn);
    return -1;
  }

  compile(pargs, yiFn);

  return 0;
}
