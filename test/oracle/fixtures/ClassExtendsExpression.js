class A extends B.C {}
const M = (S) => class extends S {};
class D extends M(A) { constructor() { super(); } }
