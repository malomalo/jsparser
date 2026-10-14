const k = 'z';
const { 'a-b': x, 0: y, [k]: z = 1, w, ...rest } = o;
function f({ "q": p, [k + 1]: { r } }) { return p + r; }
