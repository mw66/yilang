interface Person {
  @property ref string addr();
  @property ref string id();
  @property ref string name();
}

class Person_ : Person {
  private string addr_;
  @property ref string addr() {return addr_;}
  private string id_;
  @property ref string id() {return id_;}
  private string name_;
  @property ref string name() {return name_;}
}

Person newPerson() {return new Person_();}


interface UKR: Person {
}

class UKR_ : UKR {
  private string addr_;
  @property ref string addr() {return addr_;}
  private string id_;
  @property ref string id() {return id_;}
  private string name_;
  @property ref string name() {return name_;}
}

UKR newUKR() {return new UKR_();}


interface USR: Person {
}

class USR_ : USR {
  private string addr_;
  @property ref string addr() {return addr_;}
  private string id_;
  @property ref string id() {return id_;}
  private string name_;
  @property ref string name() {return name_;}
}

USR newUSR() {return new USR_();}


interface Visitor: UKR, USR, Person {
  @property ref string ukAddr();
  @property ref string ukId();
  @property ref string usAddr();
  @property ref string usId();
  @property ref string visa();
}

class Visitor_ : Visitor {
  private string addr_;
  @property ref string addr() {return addr_;}
  private string id_;
  @property ref string id() {return id_;}
  private string name_;
  @property ref string name() {return name_;}
  private string ukAddr_;
  @property ref string ukAddr() {return ukAddr_;}
  private string ukId_;
  @property ref string ukId() {return ukId_;}
  private string usAddr_;
  @property ref string usAddr() {return usAddr_;}
  private string usId_;
  @property ref string usId() {return usId_;}
  private string visa_;
  @property ref string visa() {return visa_;}
}

Visitor newVisitor() {return new Visitor_();}

