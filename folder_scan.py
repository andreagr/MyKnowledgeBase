"""Scan watched folders and index PDFs in place."""

import uuid
from pathlib import Path
from typing import Any, Callable

from qdrant_client.models import FieldCondition, Filter, MatchValue, PointStruct

import connections_store

PDF_EXTENSIONS = {".pdf"}


def document_id_for_path(file_path: Path) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, str(file_path.resolve())))


def discover_pdfs(root: Path, recursive: bool = True) -> list[Path]:
    if not root.is_dir():
        return []

    pdfs: list[Path] = []
    if recursive:
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in PDF_EXTENSIONS:
                pdfs.append(path)
    else:
        for path in root.iterdir():
            if path.is_file() and path.suffix.lower() in PDF_EXTENSIONS:
                pdfs.append(path)
    return sorted(pdfs)


def delete_document_vectors(qdrant, collection_name: str, document_id: str) -> None:
    try:
        qdrant.delete(
            collection_name=collection_name,
            points_selector=Filter(
                must=[FieldCondition(key="document_id", match=MatchValue(value=document_id))]
            ),
        )
        return
    except Exception:
        pass

    offset = None
    ids_to_delete: list = []
    while True:
        results, offset = qdrant.scroll(
            collection_name=collection_name,
            limit=200,
            offset=offset,
            with_payload=True,
        )
        if not results:
            break
        for point in results:
            payload = point.payload or {}
            if payload.get("document_id") == document_id:
                ids_to_delete.append(point.id)
        if offset is None:
            break

    if ids_to_delete:
        qdrant.delete(collection_name=collection_name, points_selector=ids_to_delete)


def index_pdf_at_path(
    file_path: Path,
    document_id: str,
    *,
    chunk_text: Callable[[str], list[str]],
    embed_text: Callable[[str], list[float]],
    extract_pdf_pages: Callable[[Path], tuple[int, list[dict]]],
    qdrant,
    collection_name: str,
    documents: dict[str, dict],
    source_type: str = "folder",
    folder_id: str | None = None,
    replace_existing: bool = False,
) -> dict[str, Any]:
    resolved = file_path.resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"File not found: {resolved}")

    if replace_existing:
        delete_document_vectors(qdrant, collection_name, document_id)

    pages_count, pages = extract_pdf_pages(resolved)
    points = []
    total_chunks = 0

    for page in pages:
        chunks = chunk_text(page["text"])
        for chunk in chunks:
            vector = embed_text(chunk)
            points.append(
                PointStruct(
                    id=str(uuid.uuid4()),
                    vector=vector,
                    payload={
                        "document_id": document_id,
                        "filename": resolved.name,
                        "page": page["page"],
                        "text": chunk,
                        "path": str(resolved),
                        "source_type": source_type,
                        "folder_id": folder_id,
                    },
                )
            )
            total_chunks += 1

    if points:
        qdrant.upsert(collection_name=collection_name, points=points)

    stat = resolved.stat()
    connections_store.mark_file_indexed(
        str(resolved),
        document_id,
        resolved.name,
        stat.st_mtime,
        stat.st_size,
        folder_id,
    )

    doc_meta = {
        "id": document_id,
        "filename": resolved.name,
        "pages": pages_count,
        "chunks": total_chunks,
        "path": str(resolved),
        "source_type": source_type,
        "folder_id": folder_id,
        "indexed_at": connections_store.get_document_indexed_at(document_id)
        or connections_store._utc_now(),
    }
    documents[document_id] = doc_meta
    return doc_meta


def scan_folder(
    folder: dict[str, Any],
    *,
    chunk_text: Callable[[str], list[str]],
    embed_text: Callable[[str], list[float]],
    extract_pdf_pages: Callable[[Path], tuple[int, list[dict]]],
    qdrant,
    collection_name: str,
    documents: dict[str, dict],
) -> dict[str, Any]:
    folder_id = folder["id"]
    root = Path(folder["path"])

    if not root.is_dir():
        message = f"Folder not found: {root}"
        connections_store.update_folder_scan_status(folder_id, "error", message)
        raise FileNotFoundError(message)

    pdfs = discover_pdfs(root, recursive=folder.get("recursive", True))
    indexed = 0
    skipped = 0
    updated = 0
    errors: list[str] = []

    for pdf_path in pdfs:
        try:
            resolved = pdf_path.resolve()
            stat = resolved.stat()
            existing = connections_store.get_indexed_file(str(resolved))
            document_id = (
                existing["document_id"]
                if existing
                else document_id_for_path(resolved)
            )

            if existing and existing["file_mtime"] == stat.st_mtime and existing["file_size"] == stat.st_size:
                documents[document_id] = {
                    "id": document_id,
                    "filename": existing["filename"],
                    "pages": documents.get(document_id, {}).get("pages", 0),
                    "chunks": documents.get(document_id, {}).get("chunks", 0),
                    "path": str(resolved),
                    "source_type": "folder",
                    "folder_id": folder_id,
                    "indexed_at": existing["indexed_at"],
                }
                skipped += 1
                continue

            replace = existing is not None
            index_pdf_at_path(
                resolved,
                document_id,
                chunk_text=chunk_text,
                embed_text=embed_text,
                extract_pdf_pages=extract_pdf_pages,
                qdrant=qdrant,
                collection_name=collection_name,
                documents=documents,
                source_type="folder",
                folder_id=folder_id,
                replace_existing=replace,
            )
            if replace:
                updated += 1
            else:
                indexed += 1
        except Exception as exc:
            errors.append(f"{pdf_path.name}: {exc}")

    message = (
        f"Found {len(pdfs)} PDF(s): {indexed} new, {updated} updated, {skipped} unchanged."
    )
    if errors:
        message += f" {len(errors)} error(s)."
    status = "ok" if not errors else ("partial" if indexed or updated else "error")
    connections_store.update_folder_scan_status(
        folder_id, status, message, new_files=indexed + updated
    )

    return {
        "found": len(pdfs),
        "indexed": indexed,
        "updated": updated,
        "skipped": skipped,
        "errors": errors,
        "message": message,
    }


def scan_all_folders(
    folders: list[dict[str, Any]],
    **kwargs,
) -> dict[str, Any]:
    total_indexed = 0
    total_updated = 0
    total_skipped = 0
    all_errors: list[str] = []

    for folder in folders:
        if not folder.get("enabled", True):
            continue
        try:
            result = scan_folder(folder, **kwargs)
            total_indexed += result["indexed"]
            total_updated += result["updated"]
            total_skipped += result["skipped"]
            all_errors.extend(result["errors"])
        except Exception as exc:
            all_errors.append(f"{folder.get('name', folder['id'])}: {exc}")

    message = (
        f"Scanned {len(folders)} folder(s): {total_indexed} new, "
        f"{total_updated} updated, {total_skipped} unchanged."
    )
    if all_errors:
        message += f" {len(all_errors)} error(s)."

    return {
        "folders_scanned": len(folders),
        "indexed": total_indexed,
        "updated": total_updated,
        "skipped": total_skipped,
        "errors": all_errors,
        "message": message,
    }
