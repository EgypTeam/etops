#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
.NET/C# application inspector.
- Recursively discovers .NET projects (*.csproj) from a root directory.
- Builds a cross-project graph (project references, NuGet package dependencies).
- Scans C# sources (*.cs) and summarizes namespaces, types, and methods.
- Emits a JSON file with a rich summary.

Usage:
  python dotnet_app_inspector.py [--dir /path/to/app] [--out /path/to/output.json]

If --out is omitted, defaults to: appinfo_YYYYMMDDHHMMSS.json
"""

import argparse
import json
import os
import re
import sys
import traceback
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import xml.etree.ElementTree as ET

# ---------------------------
# Utilities
# ---------------------------

TIMESTAMP_FMT = "%Y%m%d%H%M%S"

WS_RE = re.compile(r"\s+")
MOD_SPLIT_RE = re.compile(r"\s+")

def now_timestamp() -> str:
    return datetime.utcnow().strftime(TIMESTAMP_FMT)

def default_output_name() -> str:
    return f"appinfo_{now_timestamp()}.json"

def read_text_safe(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return p.read_text(errors="replace")

def normalize_ws(s: str) -> str:
    return WS_RE.sub(" ", s).strip()

# ---------------------------
# C# comment / string stripper
# ---------------------------

def strip_csharp_comments_and_strings(code: str) -> str:
    """
    Produce a mirror of the given C# code where comments and string literals are
    replaced by spaces/newlines (preserving positions and newlines).
    Handles:
      - // line comments
      - /* block comments */
      - "regular strings" with escapes
      - @"" verbatim strings
      - 'c' char literals
    """
    result = []
    i, n = 0, len(code)
    in_sl_comment = in_ml_comment = in_str = in_verbatim_str = in_char = False

    while i < n:
        ch = code[i]
        ch2 = code[i + 1] if i + 1 < n else ""

        if in_sl_comment:
            result.append("\n" if ch == "\n" else " ")
            if ch == "\n":
                in_sl_comment = False
            i += 1
            continue

        if in_ml_comment:
            if ch == "*" and ch2 == "/":
                in_ml_comment = False
                result.append(" ")
                result.append(" ")
                i += 2
            else:
                result.append("\n" if ch == "\n" else " ")
                i += 1
            continue

        if in_verbatim_str:
            # Verbatim strings end with a " not preceded by another "
            if ch == '"' and ch2 == '"':
                # escaped "" inside verbatim string
                result.append(" ")
                result.append(" ")
                i += 2
                continue
            if ch == '"':
                in_verbatim_str = False
                result.append(" ")
                i += 1
                continue
            result.append("\n" if ch == "\n" else " ")
            i += 1
            continue

        if in_str:
            if ch == "\\" and (i + 1) < n:
                result.append(" ")
                result.append(" ")
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
                result.append(" ")
                result.append(" ")
                i += 2
                continue
            if ch == "'":
                in_char = False
                result.append(" ")
            else:
                result.append(" ")
            i += 1
            continue

        # Enter comment or string states
        if ch == "/" and ch2 == "/":
            in_sl_comment = True
            result.append(" ")
            result.append(" ")
            i += 2
            continue
        if ch == "/" and ch2 == "*":
            in_ml_comment = True
            result.append(" ")
            result.append(" ")
            i += 2
            continue
        if ch == "@" and ch2 == '"':
            in_verbatim_str = True
            result.append(" ")
            result.append(" ")
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

# ---------------------------
# C# parsing (namespaces, types, methods)
# ---------------------------

NAMESPACE_RE = re.compile(
    r"(?m)^\s*namespace\s+([A-Za-z_][\w\.]*)(?:\s*;|\s*\{)"
)

TYPE_RE = re.compile(
    r"(?P<mods>(?:public|internal|protected|private|static|abstract|sealed|partial|readonly|ref)\s+)*"
    r"(?P<kind>class|interface|struct|enum|record)\s+"
    r"(?P<name>[A-Za-z_]\w*)"
    r"(?:\s*<[^>{}]+>)?"            # generic type params (rough)
    r"(?:\s*:\s*(?P<bases>[^{\n]+))?"  # base types / interfaces
    r"\s*\{",
    flags=re.MULTILINE
)

METHOD_RE = re.compile(
    r"(?P<mods>(?:public|internal|protected|private|static|virtual|abstract|override|sealed|async|extern|unsafe|new)\s+)*"
    r"(?P<typeparams><[^>{}]+>\s+)?"
    # return type (rough)
    r"(?P<rettype>[A-Za-z_][\w\.\[\]<>,? \t]*?)\s+"
    r"(?P<name>[A-Za-z_]\w*)\s*"
    r"\((?P<params>[^\)]*)\)"
    r"\s*(?:where\s+[^{]+)?"
    r"\s*(?:\{|=>|;)",
    flags=re.MULTILINE
)

CTOR_RE = re.compile(
    r"(?P<mods>(?:public|internal|protected|private|static|extern|unsafe|new)\s+)*"
    r"(?P<name>[A-Za-z_]\w*)\s*"
    r"\((?P<params>[^\)]*)\)"
    r"\s*(?:\{|=>|;)",
    flags=re.MULTILINE
)

def split_params(param_block: str) -> List[str]:
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
    p = p.strip()
    if not p:
        return {}
    # attributes [Something(...)] can appear; strip them roughly
    p_wo_attr = re.sub(r"\[[^\]]*\]", " ", p)
    tokens = p_wo_attr.strip().split()
    if not tokens:
        return {"raw": p}
    name = tokens[-1]
    type_tokens = tokens[:-1]
    if not type_tokens:
        return {"raw": p, "name": name}
    t = " ".join(type_tokens)
    return {
        "type": t,
        "name": name,
        "raw": p,
    }

def collect_leading_attributes(stripped_code: str, start_idx: int) -> List[str]:
    """
    Collects contiguous attribute lines (starting with '[') immediately
    preceding a declaration (class/method/etc).
    """
    attrs = []
    i = start_idx
    while True:
        prev_nl = stripped_code.rfind("\n", 0, i)
        if prev_nl == -1:
            break
        line_start = stripped_code.rfind("\n", 0, prev_nl)
        line_start = 0 if line_start == -1 else line_start + 1
        line = stripped_code[line_start:prev_nl].strip()
        if not line:
            i = line_start
            continue
        if line.startswith("["):
            attrs.append(line)
            i = line_start
            continue
        break
    attrs.reverse()
    return attrs

def parse_csharp_file(cs_path: Path) -> Dict:
    raw = read_text_safe(cs_path)
    stripped = strip_csharp_comments_and_strings(raw)

    ns_match = NAMESPACE_RE.search(stripped)
    namespace = ns_match.group(1) if ns_match else None

    types = []
    # Collect type locations for mapping methods/ctors
    type_locs = []

    for m in TYPE_RE.finditer(stripped):
        start = m.start()
        kind = m.group("kind")
        name = m.group("name")
        mods = (m.group("mods") or "").strip()
        bases = (m.group("bases") or None)

        def norm_list(x):
            if not x:
                return []
        # split by comma
            return [normalize_ws(s) for s in x.split(",") if s.strip()]

        base_types = norm_list(bases)
        attributes = collect_leading_attributes(stripped, start)

        type_info = {
            "kind": kind,
            "name": name,
            "modifiers": [t for t in MOD_SPLIT_RE.split(mods.strip()) if t] if mods else [],
            "base_types": base_types,
            "attributes": attributes,
            "methods": [],
            "constructors": [],
        }
        types.append(type_info)
        type_locs.append((start, len(types) - 1))

    # helper: owning type index by position
    if types:
        boundaries = [(m.start(), m.group("name")) for m in TYPE_RE.finditer(stripped)]
        boundaries.sort()
        boundaries.append((len(stripped) + 1, None))

        def owning_type_index(pos: int) -> Optional[int]:
            for i in range(len(boundaries) - 1):
                if boundaries[i][0] <= pos < boundaries[i + 1][0]:
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
            attributes = collect_leading_attributes(stripped, pos)

            params_split = split_params(params_raw)
            params = [parse_param(p) for p in params_split] if params_split else []

            proto_parts = []
            if mods:
                proto_parts.append(mods.strip())
            if typeparams:
                proto_parts.append(typeparams.strip())
            proto_parts.append(rettype)
            proto_parts.append(f"{name}({normalize_ws(params_raw)})")
            prototype = " ".join(proto_parts)

            types[idx]["methods"].append({
                "name": name,
                "modifiers": [t for t in MOD_SPLIT_RE.split(mods.strip()) if t] if mods else [],
                "type_params": typeparams.strip() if typeparams else None,
                "return_type": rettype,
                "parameters": params,
                "attributes": attributes,
                "prototype": prototype.strip(),
            })

        # Constructors
        for mc in CTOR_RE.finditer(stripped):
            pos = mc.start()
            idx = owning_type_index(pos)
            if idx is None or idx >= len(types):
                continue
            ctor_name = mc.group("name")
            owning_type_name = types[idx]["name"]
            if ctor_name != owning_type_name:
                # Skip if not same as type (to avoid false positives)
                continue
            mods = (mc.group("mods") or "").strip()
            params_raw = mc.group("params") or ""
            attributes = collect_leading_attributes(stripped, pos)

            params_split = split_params(params_raw)
            params = [parse_param(p) for p in params_split] if params_split else []

            proto_parts = []
            if mods:
                proto_parts.append(mods.strip())
            proto_parts.append(f"{ctor_name}({normalize_ws(params_raw)})")
            prototype = " ".join(proto_parts)

            types[idx]["constructors"].append({
                "name": ctor_name,
                "modifiers": [t for t in MOD_SPLIT_RE.split(mods.strip()) if t] if mods else [],
                "parameters": params,
                "attributes": attributes,
                "prototype": prototype.strip(),
            })

    return {
        "path": str(cs_path),
        "namespace": namespace,
        "types": types,
    }

# ---------------------------
# .csproj parsing
# ---------------------------

def _xml_text(el: Optional[ET.Element]) -> Optional[str]:
    return el.text.strip() if el is not None and el.text else None

def parse_csproj(csproj_path: Path) -> Dict:
    """
    Parse basic .NET csproj fields:
      - AssemblyName, RootNamespace, TargetFramework(s), OutputType
      - ProjectReference, PackageReference
    """
    text = read_text_safe(csproj_path)
    # csproj usually has default ns; strip if needed for simpler XPath
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        root = ET.fromstring(re.sub(r'xmlns="[^"]+"', "", text))

    # Remove namespaces for easier access
    for el in root.iter():
        if "}" in el.tag:
            el.tag = el.tag.split("}", 1)[1]

    props = {}
    for pg in root.findall("PropertyGroup"):
        for child in pg:
            tag = child.tag
            val = _xml_text(child)
            if not val:
                continue
            # Keep first occurrence; later we might override some by design
            if tag not in props:
                props[tag] = val

    assembly_name = props.get("AssemblyName")
    root_ns = props.get("RootNamespace")
    output_type = props.get("OutputType")

    # TargetFramework or TargetFrameworks
    tfs = []
    if "TargetFramework" in props:
        tfs.append(props["TargetFramework"])
    if "TargetFrameworks" in props:
        for tf in props["TargetFrameworks"].split(";"):
            tf = tf.strip()
            if tf:
                tfs.append(tf)
    tfs = sorted(set(tfs))

    # ProjectReference
    project_refs = []
    for ig in root.findall("ItemGroup"):
        for pr in ig.findall("ProjectReference"):
            include = pr.get("Include")
            if not include:
                continue
            ref = {
                "include": include,
                "name": _xml_text(pr.find("Name")) or None,
                "project_guid": _xml_text(pr.find("Project")) or None,
            }
            project_refs.append(ref)

    # PackageReference
    package_refs = []
    for ig in root.findall("ItemGroup"):
        for pr in ig.findall("PackageReference"):
            include = pr.get("Include")
            version = pr.get("Version") or _xml_text(pr.find("Version")) or None
            if not include:
                continue
            package_refs.append({
                "name": include,
                "version": version,
                "include": include,
            })

    return {
        "csproj_path": str(csproj_path),
        "dir": str(csproj_path.parent),
        "assembly_name": assembly_name,
        "root_namespace": root_ns,
        "target_frameworks": tfs,
        "output_type": output_type,
        "project_references": project_refs,
        "package_references": package_refs,
    }

# ---------------------------
# Discovery & aggregation
# ---------------------------

def discover_csprojs(root: Path) -> List[Path]:
    csprojs = []
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            if fn.lower().endswith(".csproj"):
                csprojs.append(Path(dirpath) / fn)
    return csprojs

def summarize_sources(project_dir: Path) -> Dict:
    """
    Summarize C# sources for a project directory.
    - We don't restrict to specific folders (src, tests) here; we just scan all *.cs under project dir.
      You can narrow this if desired.
    """
    namespaces: Dict[str, Dict] = {}
    files = []

    for cs in project_dir.rglob("*.cs"):
        # Quick skip: ignore obj/ and bin/
        if "obj" in cs.parts or "bin" in cs.parts:
            continue
        try:
            summary = parse_csharp_file(cs)
        except Exception:
            summary = {"path": str(cs), "error": traceback.format_exc(), "types": [], "namespace": None}
        files.append(summary)
        ns = summary.get("namespace") or "(global)"
        ns_obj = namespaces.setdefault(ns, {"files": [], "types": []})
        ns_obj["files"].append(summary.get("path"))
        for t in summary.get("types", []):
            ns_obj["types"].append(t)

    return {
        "namespaces": namespaces,
        "file_count": len(files),
    }

# ---------------------------
# Relationship graph
# ---------------------------

def build_graph(projects: List[Dict]) -> Dict:
    """
    Build relationships:
      - project_references edges (from project to other internal project, if resolved)
      - package_dependencies edges (from project to NuGet package name+version)
    """
    # index projects by csproj path (normalized)
    by_path = {}
    for p in projects:
        csproj_path = Path(p["csproj_path"]).resolve()
        by_path[str(csproj_path)] = p

    project_refs = []
    package_deps = []

    for p in projects:
        from_proj = p.get("csproj_path")
        base_dir = Path(p["dir"]).resolve()

        # project refs
        for pr in p.get("project_references", []):
            include = pr.get("include")
            if not include:
                continue
            # Resolve relative path
            target_path = (base_dir / include).resolve()
            to_proj = None
            if str(target_path) in by_path:
                to_proj = by_path[str(target_path)].get("csproj_path")
            project_refs.append({
                "from": from_proj,
                "to": to_proj or str(target_path),
                "name": pr.get("name"),
                "project_guid": pr.get("project_guid"),
            })

        # package deps
        for dep in p.get("package_references", []):
            package_deps.append({
                "from": from_proj,
                "package": dep.get("name"),
                "version": dep.get("version"),
            })

    return {
        "project_references": project_refs,
        "package_dependencies": package_deps,
    }

# ---------------------------
# Main
# ---------------------------

def main():
    ap = argparse.ArgumentParser(description="Inspect .NET/C# application and emit a JSON summary.")
    ap.add_argument("--dir", "--root", dest="root", default=".",
                    help="Application root directory. Defaults to current directory.")
    ap.add_argument("--out", dest="out", default=None,
                    help="Output JSON path. Defaults to appinfo_YYYYMMDDHHMMSS.json")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"Error: root directory does not exist: {root}", file=sys.stderr)
        sys.exit(2)

    out_path = Path(args.out) if args.out else Path(default_output_name())

    csprojs = discover_csprojs(root)
    if not csprojs:
        print(f"Warning: No .csproj files found under {root}", file=sys.stderr)

    projects = []
    for csproj in csprojs:
        try:
            meta = parse_csproj(csproj)
        except Exception:
            print(f"Error parsing csproj: {csproj}", file=sys.stderr)
            traceback.print_exc()
            continue

        try:
            src_summary = summarize_sources(Path(meta["dir"]))
        except Exception:
            src_summary = {
                "error": traceback.format_exc(),
                "namespaces": {},
                "file_count": 0,
            }

        meta["source_summary"] = src_summary
        projects.append(meta)

    relationships = build_graph(projects)

    payload = {
        "generated_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "root_dir": str(root),
        "project_count": len(projects),
        "projects": projects,
        "relationships": relationships,
    }

    out_path = out_path.resolve()
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"Wrote {out_path}")

if __name__ == "__main__":
    main()
