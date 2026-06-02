import std.stdio;

abstract class ExprC {}

class NumC : ExprC {
    double val;

    this(double val) {
        this.val = val;
    }
}

class StrC : ExprC {
    string str;

    this(string str) {
        this.str = str;
    }
}

class IdC : ExprC {
    string sym;

    this(string sym) {
        this.sym = sym;
    }
}

class IfC : ExprC {
    ExprC condition;
    ExprC trueBranch;
    ExprC falseBranch;

    this(ExprC condition, ExprC trueBranch, ExprC falseBranch) {
        this.condition = condition;
        this.trueBranch = trueBranch;
        this.falseBranch = falseBranch;
    }
}

class AppC : ExprC {
    ExprC f;
    ExprC[] args;

    this(ExprC f, ExprC[] args) {
        this.f = f;
        this.args = args;
    }
}

class LamC : ExprC {
    string[] params;
    ExprC body;

    this(string[] params, ExprC body) {
        this.params = params;
        this.body = body;
    }
}


abstract class Value {}

class NumV : Value {
    double val;

    this(double val) {
        this.val = val;
    }
}

class BoolV : Value {
    bool val;

    this(bool val) {
        this.val = val;
    }
}

class StrV : Value {
    string str;

    this(string str) {
        this.str = str;
    }
}

class CloV : Value {
    string[] params;
    ExprC body;
    Bind[] env;

    this(string[] params, ExprC body, Bind[] env) {
        this.params = params;
        this.body = body;
        this.env = env;
    }
}

class PrimV : Value {
    string sym;
    Value delegate(Value[] args) body;

    this(string sym, Value delegate(Value[] args) body) {
        this.sym = sym;
        this.body = body;
    }
}

class Bind {
    string name;
    Value val;

    this(string name, Value val) {
        this.name = name;
        this.val = val;
    }
}

alias Env = Bind[];

void main() {
    writeln("Hello World!");
   
}
