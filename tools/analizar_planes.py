#!/usr/bin/env python3
"""Resume métricas y operadores de planes SQL Server .sqlplan (XML)."""
from __future__ import annotations
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET


def attr(element: ET.Element, name: str, default: str = "") -> str:
    return element.attrib.get(name, default)


def summarize(path: Path) -> dict:
    root = ET.parse(path).getroot()
    statements = root.findall(".//{*}StmtSimple")
    if not statements:
        statements = root.findall(".//StmtSimple")
    operators: dict[str, int] = {}
    tables: set[str] = set()
    missing: set[str] = set()
    for op in root.findall(".//{*}RelOp") + root.findall(".//RelOp"):
        name = attr(op, "PhysicalOp", "Unknown")
        operators[name] = operators.get(name, 0) + 1
    for obj in root.findall(".//{*}Object") + root.findall(".//Object"):
        table = attr(obj, "Table")
        schema = attr(obj, "Schema")
        if table:
            tables.add(f"{schema}.{table}" if schema else table)
    for group in root.findall(".//{*}MissingIndexGroup") + root.findall(".//MissingIndexGroup"):
        for index in group.findall(".//{*}MissingIndex") + group.findall(".//MissingIndex"):
            database = attr(index, "Database")
            schema = attr(index, "Schema")
            table = attr(index, "Table")
            missing.add(f"{database}.{schema}.{table}".strip("."))
    statement_data = []
    for stmt in statements:
        statement_data.append({
            "text": attr(stmt, "StatementText", "(texto no disponible)").strip(),
            "cost": attr(stmt, "StatementSubTreeCost", "n/d"),
            "estimated_rows": attr(stmt, "StatementEstRows", "n/d"),
        })
    return {
        "name": path.name,
        "statements": statement_data,
        "operators": operators,
        "tables": sorted(tables),
        "missing_indexes": sorted(missing),
    }


def print_report(label: str, directory: Path) -> None:
    plans = sorted(directory.glob("*.sqlplan")) if directory.exists() else []
    print(f"\n=== {label}: {directory} ===")
    if not plans:
        print("No se encontraron archivos .sqlplan.")
        return
    for path in plans:
        try:
            data = summarize(path)
        except (ET.ParseError, OSError) as exc:
            print(f"\n{path.name}: no se pudo leer ({exc})")
            continue
        print(f"\n{data['name']}")
        for stmt in data["statements"]:
            print(f"  Costo subárbol estimado: {stmt['cost']} | filas estimadas: {stmt['estimated_rows']}")
            print(f"  SQL: {stmt['text']}")
        print("  Tablas: " + (", ".join(data["tables"]) or "no identificadas"))
        print("  Operadores: " + (", ".join(f"{k}={v}" for k, v in sorted(data["operators"].items())) or "no identificados"))
        print("  Índices sugeridos por el optimizador: " + (", ".join(data["missing_indexes"]) or "ninguno"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("antes", type=Path, help="Carpeta con planes .sqlplan de línea base")
    parser.add_argument("despues", type=Path, nargs="?", help="Carpeta opcional con planes posteriores")
    args = parser.parse_args()
    print_report("ANTES", args.antes)
    if args.despues:
        print_report("DESPUÉS", args.despues)
    print("\nNota: costo estimado no equivale a duración real. Confirma lecturas y tiempo en STATISTICS IO/TIME.")


if __name__ == "__main__":
    main()
