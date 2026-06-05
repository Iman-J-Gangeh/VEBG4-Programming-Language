import std.stdio;
import std.conv;

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

    // primatives not implemented 
    env ~= new Bind("<=", new PrimV("<=", &leqop));
    env ~= new Bind("substring", new PrimV("substring", &substringOp));
    env ~= new Bind("strlen", new PrimV("strlen", &strlenOp));
    env ~= new Bind("equal?", new PrimV("equal?", &equalOp));
    env ~= new Bind("error", new PrimV("error", &erroOp));
    env ~= new Bind("strlen", new PrimV("strlen", &strlenOp));
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
            Env new_env = extendEnvMultiple(clov.params, argVals, clo.env);
            return interp(clo.body, new_env);
        }

        throw new Exception("VEBG: expected a primitive function");
    }

    throw new Exception("VEBG: unknown expression");
}

void main() {
    Env env = topEnv();

    writeln(serialize(interp(new NumC(5), env)));
    writeln(serialize(interp(new StrC("lebg4"), env)));
    writeln(serialize(interp(new IdC("true"), env)));

    writeln(serialize(interp(
        new AppC(new IdC("+"), [new NumC(2), new NumC(3)]),
        env)));

    writeln(serialize(interp(
        new AppC(new IdC("*"), [new NumC(3), new NumC(5)]),
        env)));

    writeln(serialize(interp(
        new AppC(new IdC("+"),
                 [new NumC(2),
                  new AppC(new IdC("*"), [new NumC(3), new NumC(4)])]),
        env)));
}