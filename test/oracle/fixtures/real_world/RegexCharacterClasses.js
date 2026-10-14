this._agsAdmin=/(https?:\/\/[^/]+\/[^/]+)\/admin\/?(\/.*)?$/i
function T(e){return e.replaceAll(/[|\{}()[\]^$+*?.]/g,"\$&")}
f=/(?:LENGTH)?UNIT\[([^\]]+)]]$/i
function o(t,e){return t.replaceAll(/([.$?*|{}()[\]\\/+\-^])/g,(t=>e?.includes(t)?t:`\${t}`))}
