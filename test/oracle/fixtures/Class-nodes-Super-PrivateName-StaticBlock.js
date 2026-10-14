class A extends B { x = 1; #y = 2; static z; #m() {} constructor() { super(); super.m(); } static { init(); } get v() { return this.#y } static async *w() {} }
