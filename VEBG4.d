import std.stdio;
import std.conv;
import std.string;

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
    Value function(Value[] args) body;

    this(string sym, Value function(Value[] args) body) {
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

// extends an environment with a single value binding
// takes a Bind and Env, and returns the extended Env
Env extendEnv(Bind b, Env env) {
    return [b] ~ env;
}

// extends an environment with multiple value and parameter bindings, takes a list of strings,
// a list of Values and an env, and returns the extended environment
Env extendEnvMultiple(string[] params, Value[] vals, Env env) {
    if (params.length != vals.length) {
        throw new Exception("VEBG: wrong number of arguments");
    }

    Env newEnv = env;

    for (int i = cast(int) params.length - 1; i >= 0; i--) {
        newEnv = extendEnv(new Bind(params[i], vals[i]), newEnv);
    }

    return newEnv;
}

// takes a string id and env, looks up the id in env, and returns a Value
Value lookup(string id, Env env) {
    foreach (b; env) {
        if (b.name == id) {
            return b.val;
        }
    }

    throw new Exception("VEBG: unbound identifier " ~ id);
}

// converts a value into its output string
string serialize(Value v) {
    if (auto n = cast(NumV) v) {
        return to!string(n.val);
    }
    else if (auto b = cast(BoolV) v) {
        return b.val ? "true" : "false";
    }
    else if (auto s = cast(StrV) v) {
        return "\"" ~ s.str ~ "\"";
    }
    else if (cast(CloV) v) {
        return "#<procedure>";
    }
    else if (cast(PrimV) v) {
        return "#<primop>";
    }

    throw new Exception("VEBG: unknown value");
}

// PRIMITIVES

// HELPER FUNCTION: checks that a Value is NumV and returns it, used in binop and divop
NumV expectedNum(Value v, string opName) {
    auto n = cast(NumV) v;

    if (n is null) {
        throw new Exception("VEBG: " ~ opName ~ " expected a number");
    }

    return n;
}

// HELPER FUNCTION: checks that a Value is StrV and returns it
StrV expectedStr(Value v, string opName) {
    auto s = cast(StrV) v;
 
    if (s is null) {
        throw new Exception("VEBG: " ~ opName ~ " expected a string, got " ~ serialize(v));
    }
 
    return s;
}
 
// HELPER FUNCTION: checks that a Value is a non-negative integer (natural number) and returns it
long expectedNatural(Value v, string opName) {
    auto n = cast(NumV) v;
 
    if (n is null) {
        throw new Exception("VEBG: " ~ opName ~ " expected a natural number, got " ~ serialize(v));
    }
 
    double d = n.val;
 
    if (d < 0 || d != cast(long) d) {
        throw new Exception("VEBG: " ~ opName ~ " expected a natural number, got " ~ serialize(v));
    }
 
    return cast(long) d;
}
 
// HELPER FUNCTIONS for binop
double add(double a, double b) {
    return a + b;
}
double sub(double a, double b) {
    return a - b;
}
double mul(double a, double b) {
    return a * b;
}

// HELPER FUNCTION: handles binary numeric operations 
Value binop(Value[] args, string opName, double function(double, double) f) {
    if (args.length != 2) {
        throw new Exception("VEBG: " ~ opName ~ " expected two arguments");
    }

    auto num1 = expectedNum(args[0], opName);
    auto num2 = expectedNum(args[1], opName);

    return new NumV(f(num1.val, num2.val));
}

// primitive ops
Value plusOp(Value[] args) {
    return binop(args, "+", &add);
}
Value minusOp(Value[] args) {
    return binop(args, "-", &sub);
}
Value multOp(Value[] args) {
    return binop(args, "*", &mul);
}

// divides two numbers and returns a NumV
Value divOp(Value[] args) {
    if (args.length != 2) {
        throw new Exception("VEBG: / expected two arguments");
    }

    auto a = expectedNum(args[0], "/");
    auto b = expectedNum(args[1], "/");

    if (b.val == 0) {
        throw new Exception("VEBG: cannot divide by zero");
    }

    return new NumV(a.val / b.val);
}

// returns true if a <= b, errors if either is not a number
Value leqOp(Value[] args) {
    if (args.length != 2) {
        throw new Exception("VEBG: <= expected two arguments");
    }
 
    auto a = expectedNum(args[0], "<=");
    auto b = expectedNum(args[1], "<=");
 
    return new BoolV(a.val <= b.val);
}
 
// returns a substring from start up to (not including) stop
Value substringOp(Value[] args) {
    if (args.length != 3) {
        throw new Exception("VEBG: substring expected three arguments");
    }
 
    auto s     = expectedStr(args[0], "substring");
    long start = expectedNatural(args[1], "substring");
    long stop  = expectedNatural(args[2], "substring");
 
    if (start > stop || stop > cast(long) s.str.length) {
        throw new Exception("VEBG: substring index out of range");
    }
 
    return new StrV(s.str[cast(size_t) start .. cast(size_t) stop]);
}
 
// returns the length of a string as a NumV
Value strlenOp(Value[] args) {
    if (args.length != 1) {
        throw new Exception("VEBG: strlen expected one argument");
    }
 
    auto s = expectedStr(args[0], "strlen");
 
    return new NumV(cast(double) s.str.length);
}
 
// returns true if both values are equal numbers, booleans, or strings;
// returns false if either is a closure or primop, or if types differ
Value equalOp(Value[] args) {
    if (args.length != 2) {
        throw new Exception("VEBG: equal? expected two arguments");
    }
 
    Value a = args[0];
    Value b = args[1];
 
    if (cast(CloV) a || cast(CloV) b) return new BoolV(false);
    if (cast(PrimV) a || cast(PrimV) b) return new BoolV(false);
 
    if (auto an = cast(NumV) a) {
        if (auto bn = cast(NumV) b) return new BoolV(an.val == bn.val);
        return new BoolV(false);
    }
    if (auto ab = cast(BoolV) a) {
        if (auto bb = cast(BoolV) b) return new BoolV(ab.val == bb.val);
        return new BoolV(false);
    }
    if (auto as_ = cast(StrV) a) {
        if (auto bs = cast(StrV) b) return new BoolV(as_.str == bs.str);
        return new BoolV(false);
    }
 
    return new BoolV(false);
}
 
// halts the program with a user-error containing the serialized value
Value errorOp(Value[] args) {
    if (args.length != 1) {
        throw new Exception("VEBG: error expected one argument");
    }
 
    throw new Exception("VEBG: user-error " ~ serialize(args[0]));
}
 
// prints a value to stdout and returns it
Value printlnOp(Value[] args) {
    if (args.length != 1) {
        throw new Exception("VEBG: println expected one argument");
    }
 
    writeln(serialize(args[0]));
 
    return args[0];
}
 
// concatenates two strings and returns a StrV
Value plusplusOp(Value[] args) {
    if (args.length != 2) {
        throw new Exception("VEBG: ++ expected two arguments");
    }
 
    auto a = expectedStr(args[0], "++");
    auto b = expectedStr(args[1], "++");
 
    return new StrV(a.str ~ b.str);
}
 
// evaluates both arguments and returns the second, discarding the first
Value chainOp(Value[] args) {
    if (args.length != 2) {
        throw new Exception("VEBG: chain expected two arguments");
    }
 
    return args[1];
}
 
// reads a number from stdin and returns a NumV
Value readnumOp(Value[] args) {
    if (args.length != 0) {
        throw new Exception("VEBG: read-num expected no arguments");
    }
 
    string line = strip(readln());
 
    try {
        return new NumV(to!double(line));
    } catch (Exception e) {
        throw new Exception("VEBG: read-num could not parse input as number");
    }
}
 
// reads a line from stdin and returns a StrV
Value readstrOp(Value[] args) {
    if (args.length != 0) {
        throw new Exception("VEBG: read-str expected no arguments");
    }
 
    return new StrV(strip(readln()));
}
 
// END OF PRIMITIVES

// creates the starting environment with primitive functions and booleans
Env topEnv() {
    Env env;

    env ~= new Bind("+", new PrimV("+", &plusOp));
    env ~= new Bind("-", new PrimV("-", &minusOp));
    env ~= new Bind("*", new PrimV("*", &multOp));
    env ~= new Bind("/", new PrimV("/", &divOp));
    env ~= new Bind("true", new BoolV(true));
    env ~= new Bind("false", new BoolV(false));
    env ~= new Bind("<=", new PrimV("<=", &leqOp));
    env ~= new Bind("substring", new PrimV("substring", &substringOp));
    env ~= new Bind("strlen", new PrimV("strlen", &strlenOp));
    env ~= new Bind("equal?", new PrimV("equal?", &equalOp));
    env ~= new Bind("error", new PrimV("error", &errorOp));
    env ~= new Bind("println", new PrimV("println", &printlnOp));
    env ~= new Bind("++", new PrimV("++", &plusplusOp));
    env ~= new Bind("chain", new PrimV("chain", &chainOp));
    env ~= new Bind("read-num", new PrimV("read-num", &readnumOp));
    env ~= new Bind("read-str", new PrimV("read-str", &readstrOp));
    return env;
}

// interprets an ExprC using the given environment and returns a Value
Value interp (ExprC expr, Env env) {
    if (auto n = cast(NumC) expr) {
        return new NumV(n.val);
    }
    if (auto s = cast(StrC) expr) {
        return new StrV(s.str);
    }
    if (auto id = cast(IdC) expr) {
        return lookup(id.sym, env);
    }
    if (auto closure = cast(LamC) expr) {
        return new CloV(closure.params, closure.body, env);
    }
    if (auto ifs = cast(IfC) expr) {
        auto boolVal = interp(ifs.condition, env);

        if (auto cond = cast(BoolV) boolVal) {
            if (cond.val) {
                return interp(ifs.trueBranch, env);
            } else {
                return interp(ifs.falseBranch, env);
            }
        } else {
            throw new Exception("VEBG: if condition expected a boolean got " ~ serialize(boolVal));
        }
    }
    if (auto app = cast(AppC) expr) {
        Value fVal = interp(app.f, env);

        Value[] argVals;
        foreach (arg; app.args) {
            argVals ~= interp(arg, env);
        }

        if (auto prim = cast(PrimV) fVal) {
            return prim.body(argVals);
        }

        if (auto clov = cast(CloV) fVal) {
            Env new_env = extendEnvMultiple(clov.params, argVals, clov.env);
            return interp(clov.body, new_env);
        }

        throw new Exception("VEBG: expected a primitive function");
    }

    throw new Exception("VEBG: unknown expression");

}

void checkEqual(string testName, string actual, string expected) {
    if (actual == expected) {
        writeln("PASS: ", testName);
    } else {
        writeln("FAIL: ", expected);
        writeln(" got: ", actual);
    }
}

void checkError(string testName, void delegate() thunk) {
    try {
        thunk();
        writeln("FAIL: ", testName);
        writeln(" expected an error");
    } catch (Exception e) {
        writeln("PASS: ", testName);
    }
}

void main() {
    Env env = topEnv();

checkEqual(
    "number",
    serialize(interp(new NumC(5), env)),
    "5"
);

checkEqual(
    "string",
    serialize(interp(new StrC("vebg4"), env)),
    "\"vebg4\""
);

checkEqual(
    "true id",
    serialize(interp (new IdC("true"), env)),
    "true"
);

checkEqual(
    "false id",
    serialize(interp(new IdC("false"), env)),
    "false"
);

checkEqual(
    "addition",
    serialize(interp(new AppC(new IdC("+"), [new NumC(2), new NumC(3)]),
    env)),
    "5"
);

checkEqual(
    "multiplication",
    serialize (interp(new AppC(new IdC("*"), [new NumC(3), new NumC(5)]),
    env)),
    "15"
);

checkEqual(
    "nested arithmetic",
    serialize(interp(new AppC(new IdC("+"), [new NumC(2),
    new AppC(new IdC("*"), [new NumC(3), new NumC(4)])]),
    env)),
    "14"
);

checkEqual(
    "if true",
    serialize(interp(new IfC(new IdC("true"), new NumC(1), new NumC(2)),
    env)),
    "1"
);

checkEqual(
    "if false",
    serialize(interp (new IfC(new IdC("false"), new NumC(1), new NumC(2)),
    env)),
    "2"
);

checkEqual(
    "lambda application",
    serialize(interp(new AppC(new LamC(["x"], new AppC(new IdC("+"), [new IdC("x"), new NumC(1)])),
    [new NumC(5)]),
    env)),
    "6"
);

checkEqual(
    "two argument lambda",
    serialize(interp(new AppC(new LamC(["x", "y"], new AppC(new IdC("+"), [new IdC("x"),
    new IdC("y")])),
    [new NumC(10), new NumC(4)]),
    env)),
    "14"
);

checkEqual(
        "subtraction",
        serialize(interp(new AppC(new IdC("-"), [new NumC(10), new NumC(3)]),
        env)),
        "7"
    );
 
    checkEqual(
        "division",
        serialize(interp(new AppC(new IdC("/"), [new NumC(10), new NumC(2)]),
        env)),
        "5"
    );
 
    checkEqual(
        "less than or equal true",
        serialize(interp(new AppC(new IdC("<="), [new NumC(2), new NumC(3)]),
        env)),
        "true"
    );
 
    checkEqual(
        "less than or equal false",
        serialize(interp(new AppC(new IdC("<="), [new NumC(5), new NumC(3)]),
        env)),
        "false"
    );
 
    checkEqual(
        "strlen",
        serialize(interp(new AppC(new IdC("strlen"), [new StrC("abc")]),
        env)),
        "3"
    );
 
    checkEqual(
        "substring",
        serialize(interp(new AppC(new IdC("substring"), [new StrC("hello"), new NumC(1), new NumC(4)]),
        env)),
        "\"ell\""
    );
 
    checkEqual(
        "equal? numbers true",
        serialize(interp(new AppC(new IdC("equal?"), [new NumC(5), new NumC(5)]),
        env)),
        "true"
    );
 
    checkEqual(
        "equal? numbers false",
        serialize(interp(new AppC(new IdC("equal?"), [new NumC(5), new NumC(6)]),
        env)),
        "false"
    );
 
    checkEqual(
        "equal? strings true",
        serialize(interp(new AppC(new IdC("equal?"), [new StrC("hi"), new StrC("hi")]),
        env)),
        "true"
    );
 
    checkEqual(
        "equal? closures false",
        serialize(interp(new AppC(new IdC("equal?"), [
            new LamC(["x"], new IdC("x")),
            new LamC(["y"], new IdC("y"))
        ]), env)),
        "false"
    );
 
    checkEqual(
        "closure serialize",
        serialize(interp(new LamC(["x"], new IdC("x")), env)),
        "#<procedure>"
    );
 
    checkEqual(
        "primop serialize",
        serialize(interp(new IdC("+"), env)),
        "#<primop>"
    );
 
    checkEqual(
        "string concat",
        serialize(interp(new AppC(new IdC("++"), [new StrC("hello"), new StrC(" world")]),
        env)),
        "\"hello world\""
    );
 
    checkEqual(
        "chain returns second",
        serialize(interp(new AppC(new IdC("chain"), [new NumC(1), new NumC(2)]),
        env)),
        "2"
    );
 
    checkEqual(
        "given desugaring",
        serialize(interp(new AppC(
            new LamC(["x", "y"], new AppC(new IdC("+"), [new IdC("x"), new IdC("y")])),
            [new NumC(5), new NumC(3)]),
        env)),
        "8"
    );

checkError("unbound identifier", {
    interp(new IdC("z"), env);
});

checkError("divide by zero", {
    interp(new AppC(new IdC("/"), [new NumC(10), new NumC(0)]), env);
});

checkError("if condition not boolean", {
    interp(new IfC(new NumC(5), new NumC(1), new NumC(2)), env);
});

checkError("wrong number of args", {
    interp(new AppC(new IdC("+"), [new NumC(1)]), env);
});

checkError("error op", {
        interp(new AppC(new IdC("error"), [new NumC(5)]), env);
    });
 
    checkError("strlen non-string", {
        interp(new AppC(new IdC("strlen"), [new NumC(5)]), env);
    });
 
    checkError("substring negative index", {
        interp(new AppC(new IdC("substring"), [new StrC("hello"), new NumC(-1), new NumC(3)]), env);
    });
 
    checkError("substring out of range", {
        interp(new AppC(new IdC("substring"), [new StrC("hi"), new NumC(0), new NumC(5)]), env);
    });
 
    checkError("call non-function", {
        interp(new AppC(new NumC(5), [new NumC(1)]), env);
    });
 
    checkError("wrong arity closure", {
        interp(new AppC(new LamC(["x", "y"], new IdC("x")), [new NumC(1)]), env);
    });
 
    checkError("+ with non-number", {
        interp(new AppC(new IdC("+"), [new IdC("true"), new NumC(1)]), env);
    });

}