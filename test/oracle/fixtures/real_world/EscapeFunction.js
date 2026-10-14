export function escape(string) {
    if (string !== undefined && string != null) {
        return String(string).replace(/[&<>'"\\/]/g, function (c) {
            return '&#' + c.codePointAt(0) + ';';
        });
    } else {
        return '';
    }
}

/*
    Adapted from https://github.com/thysultan/md.js
    modified to include urlRegExp
*/

var unicodes = {
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
  '&': '&amp;',
  '[': '&#91;',
  ']': '&#93;',
  '(': '&#40;',
  ')': '&#41;',
};

var resc = /[<>&\(\)\\[\\]"']/g;
