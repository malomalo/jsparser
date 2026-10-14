export default function (locals) {
  for (var x = 0; x < locals.rows; x++) {
    for (var i = 0; i < locals.columns; i++) {
      __append("\n        <td class=\"opacity-");
      __append((locals.rows - x) / locals.rows * 100);
      __append("-p ");

      __append(locals._.sample(['', '-delay', '-delay-more']));

      __append(" rounded\">\n                &nbsp;\n            </div>\n        </td>\n    ");
    }

    __append("\n    </tr>\n");
  }

  return __output.join("");
}
