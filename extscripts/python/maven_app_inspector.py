#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Maven/Java application inspector.
- Recursively discovers Maven projects (pom.xml) from a root directory.
- Builds a cross-project graph (parents, modules, dependencies).
- Scans Java sources (src/main/java, src/test/java) and summarizes packages, types, and methods.
- Emits a JSON file with a rich summary.

Usage:
  python maven_app_inspector.py [--dir /path/to/app] [--out /path/to/output.json]

If --out is omitted, defaults to: appinfo_YYYYMMDDHHIISS.json
"""

import argparse
import json
import os
import re
import sys
import traceback
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import xml.etree.ElementTree as ET

# ---------------------------
# Utilities
# ---------------------------

TIMESTAMP_FMT = "%Y%m%d%H%M%S"

JAVA_FILE_EXT = (".java",)
DEFAULT_SOURCE_DIRS = [
    os.path.join("src", "main", "java"),
    os.path.join("src", "test", "java"),
]

MOD_SPLIT_RE = re.compile(r"\s+")
WS_RE = re.compile(r"\s+")

def now_timestamp():
    return datetime.utcnow().strftime(TIMESTAMP_FMT)

def default_output_name():
    return f"appinfo_{now_timestamp()}.json"

def read_text_safe(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        # Fallback if necessary
        return p.read_text(errors="replace")

def normalize_ws(s: str) -> str:
    return WS_RE.sub(" ", s).strip()

def strip_java_comments_and_strings(code: str) -> str:
    """
    Removes // line comments, /* */ block comments, and string/char literals.
    This helps avoid false positives when regex-parsing Java structure.
    """
    # State machine over the code
    result = []
    i, n = 0, len(code)
    in_sl_comment = False
    in_ml_comment = False
    in_str = False
    in_char = False
    while i < n:
        ch = code[i]
        ch2 = code[i + 1] if i + 1 < n else ""

        if in_sl_comment:
            if ch == "\n":
                in_sl_comment = False
                result.append(ch)
            else:
                result.append(" ")
            i += 1
            continue

        if in_ml_comment:
            if ch == "*" and ch2 == "/":
                in_ml_comment = False
                result.append("  ")
                i += 2
            else:
                # keep line breaks for line numbers, replace body with spaces
                result.append("\n" if ch == "\n" else " ")
                i += 1
            continue

        if in_str:
            if ch == "\\" and (i + 1) < n:  # escape
                result.append("  ")
                i += 2
                continue
            if ch == '"':
                in_str = False
                result.append(" ")
            else:
                result.append(" ")
            i += 1
            continue

        if in_char:
            if ch == "\\" and (i + 1) < n:
                result.append("  ")
                i += 2
                continue
            if ch == "'":
                in_char = False
                result.append(" ")
            else:
                result.append(" ")
            i += 1
            continue

        # Entering states?
        if ch == "/" and ch2 == "/":
            in_sl_comment = True
            result.append("  ")
            i += 2
            continue
        if ch == "/" and ch2 == "*":
            in_ml_comment = True
            result.append("  ")
            i += 2
            continue
        if ch == '"':
            in_str = True
            result.append(" ")
            i += 1
            continue
        if ch == "'":
            in_char = True
            result.append(" ")
            i += 1
            continue

        result.append(ch)
        i += 1

    return "".join(result)

def split_params(param_block: str) -> List[str]:
    """
    Split parameters by commas while respecting nested generics and arrays.
    Returns raw parameter strings.
    """
    params = []
    if not param_block:
        return params
    depth = 0
    current = []
    for ch in param_block:
        if ch == "<":
            depth += 1
            current.append(ch)
        elif ch == ">":
            depth = max(0, depth - 1)
            current.append(ch)
        elif ch == "," and depth == 0:
            part = "".join(current).strip()
            if part:
                params.append(part)
            current = []
        else:
            current.append(ch)
    tail = "".join(current).strip()
    if tail:
        params.append(tail)
    return params

def parse_param(p: str) -> Dict:
    """
    Parse a single Java parameter into {type, name, varargs, annotations}.
    Heuristic-based; handles annotations and final.
    """
    p = p.strip()
    if not p:
        return {}
    # Extract annotations
    annos = re.findall(r"@\w+(?:\([^\)]*\))?", p)
    # Remove annotations
    p_wo_anno = re.sub(r"@\w+(?:\([^\)]*\))?", " ", p)
    tokens = p_wo_anno.strip().split()
    # Remove common modifiers like 'final'
    tokens = [t for t in tokens if t not in ("final")]
    if not tokens:
        return {"raw": p}

    # Detect varargs
    varargs = False
    # Name is typically the last token
    name = tokens[-1]
    type_tokens = tokens[:-1]
    if not type_tokens:
        # No explicit type? Unlikely, keep raw
        return {"raw": p, "name": name}

    t = " ".join(type_tokens)
    if t.endswith("..."):
        varargs = True
        t = t[:-3].strip() + "[]"

    return {
        "type": t,
        "name": name,
        "varargs": varargs,
        "annotations": annos,
        "raw": p,
    }

def collect_leading_annotations(code: str, start_idx: int) -> List[str]:
    """
    Collects contiguous annotations immediately preceding a declaration start index.
    Looks backwards line-by-line until a non-annotation line is found.
    """
    # Find line start of declaration
    line_start = code.rfind("\n", 0, start_idx) + 1
    # Walk upwards
    annotations = []
    i = line_start - 2
    while i >= 0:
        # Find start of previous line
        prev_newline = code.rfind("\n", 0, i)
        seg_start = 0 if prev_newline < 0 else prev_newline + 1
        seg = code[seg_start:i + 1].strip()
        if not seg:
            i = prev_newline - 1
            continue
        if seg.startswith("@"):
            annotations.append(seg)
            i = prev_newline - 1
            continue
        # Stop when not an annotation
        break
    annotations.reverse()
    return annotations

# ---------------------------
# POM parsing
# ---------------------------

def _xml_text(el: Optional[ET.Element]) -> Optional[str]:
    return el.text.strip() if el is not None and el.text else None

def parse_pom(pom_path: Path) -> Dict:
    """
    Parse basic Maven POM fields.
    Attempts to resolve groupId/version from self or parent (without full property interpolation).
    Returns a dict with metadata and lists of modules/dependencies.
    """
    ns = {"m": "http://maven.apache.org/POM/4.0.0"}
    text = read_text_safe(pom_path)
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        # Try without namespace (some POMs omit default ns)
        root = ET.fromstring(re.sub(r'xmlns="[^"]+"', "", text))
        ns = {"m": ""}

    def find(path: str) -> Optional[ET.Element]:
        if ns["m"]:
            return root.find(path, ns)
        return root.find(path)

    def findall(path: str) -> List[ET.Element]:
        if ns["m"]:
            return root.findall(path, ns)
        return root.findall(path)

    # Basic fields
    gid = _xml_text(find("m:groupId"))
    aid = _xml_text(find("m:artifactId"))
    ver = _xml_text(find("m:version"))
    name = _xml_text(find("m:name"))
    packaging = _xml_text(find("m:packaging")) or "jar"

    # Parent (may supply groupId/version)
    parent = find("m:parent")
    parent_info = None
    if parent is not None:
        pgid = _xml_text(parent.find("m:groupId", ns if ns["m"] else None))
        paid = _xml_text(parent.find("m:artifactId", ns if ns["m"] else None))
        pver = _xml_text(parent.find("m:version", ns if ns["m"] else None))
        prel = _xml_text(parent.find("m:relativePath", ns if ns["m"] else None))
        parent_info = {
            "groupId": pgid,
            "artifactId": paid,
            "version": pver,
            "relativePath": prel,
        }
        if gid is None:
            gid = pgid
        if ver is None:
            ver = pver

    # Modules
    modules = []
    for m in findall("m:modules/m:module"):
        t = _xml_text(m)
        if t:
            modules.append(t.strip())

    # Dependencies
    deps = []
    for d in findall("m:dependencies/m:dependency"):
        dg = _xml_text(d.find("m:groupId", ns if ns["m"] else None))
        da = _xml_text(d.find("m:artifactId", ns if ns["m"] else None))
        dv = _xml_text(d.find("m:version", ns if ns["m"] else None))
        ds = _xml_text(d.find("m:scope", ns if ns["m"] else None))
        dt = _xml_text(d.find("m:type", ns if ns["m"] else None))
        do = _xml_text(d.find("m:optional", ns if ns["m"] else None))
        deps.append({
            "groupId": dg,
            "artifactId": da,
            "version": dv,
            "scope": ds or "compile",
            "type": dt or "jar",
            "optional": (do == "true"),
            "ga": f"{dg}:{da}" if dg and da else None,
            "gav": f"{dg}:{da}:{dv}" if dg and da and dv else None,
        })

    return {
        "pom_path": str(pom_path),
        "dir": str(pom_path.parent),
        "groupId": gid,
        "artifactId": aid,
        "version": ver,
        "name": name,
        "packaging": packaging,
        "parent": parent_info,
        "modules": modules,
        "dependencies": deps,
    }

# ---------------------------
# Java parsing (types & methods)
# ---------------------------

PACKAGE_RE = re.compile(r"(?m)^\s*package\s+([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*;")
# Capture type decls (top-level): modifiers (optional), kind, name, extends/implements/permits (optional)
TYPE_RE = re.compile(
    r"(?P<mods>(?:public|protected|private|abstract|final|static|sealed|non-sealed|strictfp)\s+)*"
    r"(?P<kind>@interface|interface|enum|record|class)\s+"
    r"(?P<name>[A-Za-z_]\w*)"
    r"(?:\s*<[^>{}]+>)?"  # optional type params (rough)
    r"(?:\s+extends\s+(?P<extends>[^<{;{]+?))?"
    r"(?:\s+implements\s+(?P<implements>[^{{;]+?))?"
    r"(?:\s+permits\s+(?P<permits>[^{{;]+?))?"
    r"\s*[{;]",
    flags=re.MULTILINE
)

# Methods (non-constructor)
METHOD_RE = re.compile(
    r"(?P<mods>(?:public|protected|private|static|abstract|final|synchronized|native|strictfp|default)\s+)*"
    r"(?P<typeparams><[^>{}]+>\s+)?"
    r"(?P<rettype>[A-Za-z_][\w\.\[\]<> ?,&\?]+)\s+"
    r"(?P<name>[A-Za-z_]\w*)\s*"
    r"\((?P<params>[^\)]*)\)"
    r"\s*(?:throws\s+(?P<throws>[^;{]+))?"
    r"\s*(?:\{|;)",
    flags=re.MULTILINE
)

# Constructors (no return type)
CTOR_RE = re.compile(
    r"(?P<mods>(?:public|protected|private|static|final)\s+)*"
    r"(?P<typeparams><[^>{}]+>\s+)?"
    r"(?P<name>[A-Za-z_]\w*)\s*"
    r"\((?P<params>[^\)]*)\)"
    r"\s*(?:throws\s+(?P<throws>[^;{]+))?"
    r"\s*(?:\{|;)",
    flags=re.MULTILINE
)

def parse_java_file(java_path: Path) -> Dict:
    raw = read_text_safe(java_path)
    stripped = strip_java_comments_and_strings(raw)

    # package
    pkg_match = PACKAGE_RE.search(stripped)
    package = pkg_match.group(1) if pkg_match else None

    types = []
    for m in TYPE_RE.finditer(stripped):
        start = m.start()
        kind = m.group("kind")
        name = m.group("name")
        mods = (m.group("mods") or "").strip()
        extends = (m.group("extends") or None)
        implements = (m.group("implements") or None)
        permits = (m.group("permits") or None)

        # Normalize lists
        def norm_list(x):
            if not x: return []
            return [normalize_ws(s) for s in re.split(r"\s*,\s*", x.strip()) if s.strip()]

        extends_list = norm_list(extends)
        implements_list = norm_list(implements)
        permits_list = norm_list(permits)

        annotations = collect_leading_annotations(stripped, start)

        type_info = {
            "kind": kind,
            "name": name,
            "modifiers": [t for t in MOD_SPLIT_RE.split(mods.strip()) if t] if mods else [],
            "extends": extends_list,
            "implements": implements_list,
            "permits": permits_list,
            "annotations": annotations,
            "methods": [],
            "constructors": [],
        }

        types.append(type_info)

    # Method & ctor parsing is global; we’ll assign to last seen type by proximity (heuristic)
    # A more robust way would be a brace-level stack, but this heuristic is usually fine for top-level members.
    if types:
        # Build simple index of type start positions to map members
        locs = []
        for m in TYPE_RE.finditer(stripped):
            locs.append((m.start(), m.group("name")))
        locs.sort()
        locs.append((len(stripped) + 1, None))  # sentinel

        def owning_type_index(pos: int) -> Optional[int]:
            for i in range(len(locs) - 1):
                if locs[i][0] <= pos < locs[i + 1][0]:
                    return i
            return None

        # Methods
        for mm in METHOD_RE.finditer(stripped):
            pos = mm.start()
            idx = owning_type_index(pos)
            if idx is None or idx >= len(types):
                continue
            mods = (mm.group("mods") or "").strip()
            typeparams = (mm.group("typeparams") or "").strip()
            rettype = normalize_ws(mm.group("rettype"))
            name = mm.group("name")
            params_raw = mm.group("params") or ""
            throws = (mm.group("throws") or "").strip()
            annotations = collect_leading_annotations(stripped, pos)

            params_split = split_params(params_raw)
            params = [parse_param(p) for p in params_split] if params_split else []

            proto_parts = []
            if mods:
                proto_parts.append(mods.strip())
            if typeparams:
                proto_parts.append(typeparams.strip())
            proto_parts.append(rettype)
            proto_parts.append(f"{name}({normalize_ws(params_raw)})")
            if throws:
                proto_parts.append(f"throws {normalize_ws(throws)}")
            prototype = " ".join(proto_parts)

            types[idx]["methods"].append({
                "name": name,
                "modifiers": [t for t in MOD_SPLIT_RE.split(mods.strip()) if t] if mods else [],
                "type_params": typeparams.strip() if typeparams else None,
                "return_type": rettype,
                "parameters": params,
                "throws": [normalize_ws(s) for s in re.split(r"\s*,\s*", throws)] if throws else [],
                "annotations": annotations,
                "prototype": prototype.strip(),
            })

        # Constructors
        # We will only keep those whose name matches the type name owning the block (typical constructors).
        for mc in CTOR_RE.finditer(stripped):
            pos = mc.start()
            idx = owning_type_index(pos)
            if idx is None or idx >= len(types):
                continue
            ctor_name = mc.group("name")
            owning_type_name = types[idx]["name"]
            if ctor_name != owning_type_name:
                continue
            mods = (mc.group("mods") or "").strip()
            typeparams = (mc.group("typeparams") or "").strip()
            params_raw = mc.group("params") or ""
            throws = (mc.group("throws") or "").strip()
            annotations = collect_leading_annotations(stripped, pos)

            params_split = split_params(params_raw)
            params = [parse_param(p) for p in params_split] if params_split else []

            proto_parts = []
            if mods:
                proto_parts.append(mods.strip())
            if typeparams:
                proto_parts.append(typeparams.strip())
            proto_parts.append(f"{ctor_name}({normalize_ws(params_raw)})")
            if throws:
                proto_parts.append(f"throws {normalize_ws(throws)}")
            prototype = " ".join(proto_parts)

            types[idx]["constructors"].append({
                "name": ctor_name,
                "modifiers": [t for t in MOD_SPLIT_RE.split(mods.strip()) if t] if mods else [],
                "type_params": typeparams.strip() if typeparams else None,
                "parameters": params,
                "throws": [normalize_ws(s) for s in re.split(r"\s*,\s*", throws)] if throws else [],
                "annotations": annotations,
                "prototype": prototype.strip(),
            })

    return {
        "path": str(java_path),
        "package": package,
        "types": types,
    }

# ---------------------------
# Discovery and aggregation
# ---------------------------

def discover_poms(root: Path) -> List[Path]:
    poms = []
    for dirpath, dirnames, filenames in os.walk(root):
        if "pom.xml" in filenames:
            poms.append(Path(dirpath) / "pom.xml")
    return poms

def summarize_sources(project_dir: Path) -> Dict:
    packages: Dict[str, Dict] = {}
    files = []
    for rel_src in DEFAULT_SOURCE_DIRS:
        src_dir = project_dir / rel_src
        if not src_dir.exists():
            continue
        for fp in src_dir.rglob("*.java"):
            try:
                summary = parse_java_file(fp)
            except Exception:
                # be resilient, capture error but continue
                summary = {"path": str(fp), "error": traceback.format_exc()}
            files.append(summary)

            pkg = summary.get("package") or "(default)"
            pkg_obj = packages.setdefault(pkg, {"files": [], "types": []})
            pkg_obj["files"].append(summary.get("path"))

            for t in summary.get("types", []):
                pkg_obj["types"].append(t)

    return {
        "packages": packages,
        "file_count": len(files),
    }

def ga_key(g: Optional[str], a: Optional[str]) -> Optional[str]:
    return f"{g}:{a}" if g and a else None

def gav_key(g: Optional[str], a: Optional[str], v: Optional[str]) -> Optional[str]:
    return f"{g}:{a}:{v}" if g and a and v else None

def build_graph(projects: List[Dict]) -> Dict:
    """
    Builds relationships:
    - parent_child edges
    - module_inclusion (aggregator -> module path)
    - dependencies (from project GAV to target GAV if internal, otherwise to GA string or 'external')
    """
    # Map GA and GAV to project
    by_gav = {}
    by_ga = {}
    for p in projects:
        gid, aid, ver = p.get("groupId"), p.get("artifactId"), p.get("version")
        gk = ga_key(gid, aid)
        vk = gav_key(gid, aid, ver)
        if vk:
            by_gav[vk] = p
        if gk:
            by_ga[gk] = p

    parent_child = []
    module_inclusion = []
    dependencies = []

    # Parent-child via <parent>
    for p in projects:
        par = p.get("parent")
        if par:
            parent_gav = gav_key(par.get("groupId"), par.get("artifactId"), par.get("version"))
            child_gav = gav_key(p.get("groupId"), p.get("artifactId"), p.get("version"))
            if parent_gav and child_gav:
                parent_child.append({"parent": parent_gav, "child": child_gav})

    # Module inclusion
    for p in projects:
        modules = p.get("modules") or []
        if not modules:
            continue
        agg_gav = gav_key(p.get("groupId"), p.get("artifactId"), p.get("version"))
        base_dir = Path(p["dir"])
        for m in modules:
            module_inclusion.append({"aggregator": agg_gav, "module_path": str((base_dir / m).resolve())})

    # Dependencies
    for p in projects:
        from_gav = gav_key(p.get("groupId"), p.get("artifactId"), p.get("version"))
        if not from_gav:
            continue
        for d in p.get("dependencies", []):
            ga = d.get("ga")
            gav = d.get("gav")
            if gav and gav in by_gav:
                to = gav
            elif ga and ga in by_ga:
                # Internal project but version not matched; link to its current version
                tgt = by_ga[ga]
                to = gav_key(tgt.get("groupId"), tgt.get("artifactId"), tgt.get("version"))
            else:
                to = ga or "external"
            dependencies.append({"from": from_gav, "to": to, "scope": d.get("scope", "compile")})

    return {
        "parent_child": parent_child,
        "module_inclusion": module_inclusion,
        "dependencies": dependencies,
    }

def main():
    ap = argparse.ArgumentParser(description="Inspect Maven-based Java application and emit a JSON summary.")
    ap.add_argument("--dir", "--root", dest="root", default=".", help="Application root directory. Defaults to current directory.")
    ap.add_argument("--out", dest="out", default=None, help="Output JSON path. Defaults to appinfo_YYYYMMDDHHIISS.json")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"Error: root directory does not exist: {root}", file=sys.stderr)
        sys.exit(2)

    out_path = Path(args.out) if args.out else Path(default_output_name())

    poms = discover_poms(root)
    if not poms:
        print(f"Warning: No pom.xml files found under {root}", file=sys.stderr)

    # Parse projects
    projects = []
    for pom in poms:
        try:
            meta = parse_pom(pom)
        except Exception:
            print(f"Error parsing POM: {pom}", file=sys.stderr)
            traceback.print_exc()
            continue

        # Summarize sources for this project directory
        try:
            src_summary = summarize_sources(Path(meta["dir"]))
        except Exception:
            src_summary = {"error": traceback.format_exc(), "packages": {}, "file_count": 0}

        meta["source_summary"] = src_summary

        # Short ID helpers
        meta["ga"] = ga_key(meta.get("groupId"), meta.get("artifactId"))
        meta["gav"] = gav_key(meta.get("groupId"), meta.get("artifactId"), meta.get("version"))

        projects.append(meta)

    relationships = build_graph(projects)

    payload = {
        "generated_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "root_dir": str(root),
        "project_count": len(projects),
        "projects": projects,
        "relationships": relationships,
    }

    # Write JSON
    out_path = out_path.resolve()
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"Wrote {out_path}")

if __name__ == "__main__":
    main()
