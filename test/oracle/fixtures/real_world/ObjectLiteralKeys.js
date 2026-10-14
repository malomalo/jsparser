x = {
    a: "foo",
    b: 42,
    c: {},
    1: "number literal property",
    "foo:bar": "string literal property",
    [5 +2]: me,
    shorthandProperty,
    __proto__: prototype,

    method(parameters) {
      // …
    },

    get property() {},
    set property(value) {},

    ...spreadProperty,
}
