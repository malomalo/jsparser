// Compares each original source with JSAnalyzer's output by parsing both with
// acorn and diffing the trees.
//
//   node compare.mjs manifest.json
//
// The manifest is a JSON array of { source, output, error, stable } (written
// by oracle.rb). Prints a JSON array of { source, status, detail } where
// status is one of: ok, original_invalid, parse_error, invalid_output,
// mismatch, unstable.

import { readFileSync } from "node:fs";
import * as acorn from "acorn";

const OPTIONS = {
  ecmaVersion: "latest",
  allowHashBang: true,
  allowReturnOutsideFunction: true,
  allowAwaitOutsideFunction: true,
  allowImportExportEverywhere: true,
};

// Parses as a module, falling back to a script (for sloppy-mode code like
// `with` or octal literals). Returns [ast, sourceType] or throws.
function parse(code, sourceType) {
  const types = sourceType ? [sourceType] : ["module", "script"];
  let error;
  for (const type of types) {
    try {
      return [acorn.parse(code, { ...OPTIONS, sourceType: type }), type];
    } catch (e) {
      error = e;
    }
  }
  throw error;
}

const BODY_KEYS = { IfStatement: ["consequent", "alternate"], ForStatement: ["body"],
  ForInStatement: ["body"], ForOfStatement: ["body"], WhileStatement: ["body"],
  DoWhileStatement: ["body"], WithStatement: ["body"] };

// Removes differences JSAnalyzer makes on purpose: positions, how literals
// were written, empty statements, and braces added around single-statement
// bodies.
function normalize(node) {
  if (Array.isArray(node)) {
    return node
      .filter((n) => !(n && n.type === "EmptyStatement"))
      .map(normalize);
  }
  if (node === null || typeof node !== "object") return node;

  const out = {};
  for (const [key, value] of Object.entries(node)) {
    if (["start", "end", "loc", "range", "raw"].includes(key)) continue;
    out[key] = normalize(value);
  }

  if (node.type === "Literal") {
    if (node.regex) out.value = null;              // RegExp objects don't compare
    if (typeof node.value === "bigint") out.value = String(node.value);
  }

  for (const key of BODY_KEYS[node.type] || []) {
    const body = out[key];
    if (!body || body.type === "BlockStatement") continue;
    if (key === "alternate" && body.type === "IfStatement") continue; // else if
    out[key] = { type: "BlockStatement", body: body.type === "EmptyStatement" ? [] : [body] };
  }
  return out;
}

// The path to the first difference between a and b, or null
function diff(a, b, path = "Program") {
  if (a === b) return null;
  if (typeof a !== typeof b || a === null || b === null || typeof a !== "object") {
    return `${path}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`;
  }
  if (Array.isArray(a) !== Array.isArray(b)) return `${path}: array mismatch`;
  if (Array.isArray(a) && a.length !== b.length) {
    // Point at the first item that differs, which is usually where the
    // statements were split or merged
    const i = a.findIndex((item, i) => diff(item, b[i]) !== null);
    const at = i < 0 ? Math.min(a.length, b.length) : i;
    return `${path}[${at}]<${a[at]?.type}>: ${a.length} items != ${b.length} items`;
  }
  if (a.type !== b.type) return `${path}: ${a.type} != ${b.type}`;

  for (const key of new Set([...Object.keys(a), ...Object.keys(b)])) {
    const label = Array.isArray(a) ? `${path}[${key}]` : `${path}.${key}`;
    const d = diff(a[key], b[key], a[key]?.type ? `${label}<${a[key].type}>` : label);
    if (d) return d;
  }
  return null;
}

// The last few steps of a diff's path and the start of each value
function shorten(d) {
  const [path, ...rest] = d.split(": ");
  const steps = path.split(/(?=\.|\[)/);
  const tail = steps.length > 4 ? "…" + steps.slice(-4).join("") : path;
  const values = rest.join(": ").split(" != ").map((v) => (v.length > 70 ? v.slice(0, 70) + "…" : v));
  return `${tail}: ${values.join(" != ")}`;
}

// Where in the source the differing node is, for the report
function locate(code, ast, path) {
  let node = ast;
  for (const part of path.split(":")[0].matchAll(/\.(\w+)|\[(\d+)\]/g)) {
    const next = node?.[part[1] ?? Number(part[2])];
    if (next == null || typeof next !== "object") break;
    node = next;
  }
  if (node?.start == null) return "";
  const line = code.slice(0, node.start).split("\n").length;
  return ` (original line ${line}: ${code.slice(node.start, node.start + 80).split("\n")[0]})`;
}

const manifest = JSON.parse(readFileSync(process.argv[2], "utf8"));
const results = manifest.map(({ source, output, error, stable }) => {
  const original = readFileSync(source, "utf8");
  let originalAst, sourceType;
  try {
    [originalAst, sourceType] = parse(original);
  } catch (e) {
    return { source, status: "original_invalid", detail: e.message };
  }
  if (error) return { source, status: "parse_error", detail: error };

  const printed = readFileSync(output, "utf8");
  let printedAst;
  try {
    [printedAst] = parse(printed, sourceType);
  } catch (e) {
    const line = printed.split("\n")[(e.loc?.line ?? 1) - 1]?.trim().slice(0, 100);
    return { source, status: "invalid_output", detail: `${e.message}: ${line}` };
  }

  const d = diff(normalize(originalAst), normalize(printedAst));
  if (d) return { source, status: "mismatch", detail: shorten(d) + locate(original, originalAst, d) };
  if (!stable) return { source, status: "unstable", detail: "printing the output again changes it" };
  return { source, status: "ok" };
});

process.stdout.write(JSON.stringify(results));
