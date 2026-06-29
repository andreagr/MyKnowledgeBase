"""
Local Document RAG backend.

This module exposes a minimal FastAPI application that lets you:

1. Upload PDF files.
2. Extract page text from the PDFs.
3. Split text into chunks.
4. Generate embeddings for each chunk.
5. Store vectors and metadata in a local Qdrant database.
6. Ask questions against the indexed document corpus.
7. Download the original source PDF.

Architecture notes:
- Qdrant runs locally and stores vectors plus payload metadata.
- OpenAI embeddings are used for vector generation.
- DeepSeek is used only for chat completion through its OpenAI-compatible API.
"""

import os
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import List

from dotenv import load_dotenv
import fitz
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, FieldCondition, Filter, MatchValue, PointStruct, VectorParams
import connections_store
import embeddings
import email_sync
import folder_scan
import llm_providers
import local_llm
import paths
import settings_store

# Load environment variables from .env file
load_dotenv()


# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------

APP_NAME = "Local Document RAG"
paths.ensure_data_dirs()
DOCS_DIR = paths.get_docs_dir()
QDRANT_PATH = paths.get_qdrant_path()
COLLECTION_NAME = "company_docs"

# Embedding model (local, no API key needed)
EMBEDDING_MODEL_NAME = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
VECTOR_SIZE = 384  # all-MiniLM-L6-v2 outputs 384-dimensional vectors


# -------------------------------------------------------------------
# FastAPI app and service clients
# -------------------------------------------------------------------

app = FastAPI(title=APP_NAME)

# Load embedding model locally (ONNX via FastEmbed — no PyTorch)
models_dir = paths.get_models_dir()
embedding_model = embeddings.load_embedding_model(EMBEDDING_MODEL_NAME, models_dir)

qdrant = QdrantClient(path=QDRANT_PATH)

# Ensure the collection exists with the correct vector size
if qdrant.collection_exists(COLLECTION_NAME):
    try:
        collection_info = qdrant.get_collection(COLLECTION_NAME)
        vectors = collection_info.config.params.vectors
        current_vector_size = vectors.size if hasattr(vectors, "size") else None
        if current_vector_size is not None and current_vector_size != VECTOR_SIZE:
            print(
                f"Vector size mismatch: collection has {current_vector_size}, "
                f"but model outputs {VECTOR_SIZE}. Recreating collection..."
            )
            qdrant.delete_collection(COLLECTION_NAME)
            qdrant.create_collection(
                collection_name=COLLECTION_NAME,
                vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
            )
    except Exception as e:
        print(f"Warning: could not verify Qdrant collection config: {e}")
else:
    qdrant.create_collection(
        collection_name=COLLECTION_NAME,
        vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
    )

# In-memory metadata store for this first version.
# In production, replace this with SQLite or PostgreSQL.
DOCUMENTS = {}

connections_store.init_db()
settings_store.init_db()


def rebuild_documents_registry() -> None:
    """Load document metadata from uploads and indexed folder files."""
    for file_path in DOCS_DIR.glob("*"):
        if not file_path.is_file():
            continue

        name = file_path.name
        separator = name.find("_")
        if separator <= 0:
            continue

        document_id = name[:separator]
        filename = name[separator + 1 :]
        resolved_path = str(file_path.resolve())
        indexed_at = connections_store.get_document_indexed_at(document_id)
        if not indexed_at:
            indexed_at = datetime.fromtimestamp(
                file_path.stat().st_mtime, tz=timezone.utc
            ).isoformat()

        if document_id in DOCUMENTS:
            DOCUMENTS[document_id]["path"] = resolved_path
            DOCUMENTS[document_id].setdefault("indexed_at", indexed_at)
            continue

        DOCUMENTS[document_id] = {
            "id": document_id,
            "filename": filename,
            "pages": 0,
            "chunks": 0,
            "path": resolved_path,
            "source_type": "pdf",
            "indexed_at": indexed_at,
        }

    for entry in connections_store.list_all_indexed_files():
        document_id = entry["document_id"]
        file_path = Path(entry["file_path"])
        file_exists = file_path.is_file()
        if document_id in DOCUMENTS:
            DOCUMENTS[document_id]["path"] = str(file_path.resolve()) if file_exists else entry["file_path"]
            DOCUMENTS[document_id]["indexed_at"] = entry["indexed_at"]
            if not file_exists:
                DOCUMENTS[document_id]["broken"] = True
            continue
        DOCUMENTS[document_id] = {
            "id": document_id,
            "filename": entry["filename"],
            "pages": 0,
            "chunks": 0,
            "path": str(file_path.resolve()) if file_exists else entry["file_path"],
            "source_type": "folder",
            "folder_id": entry.get("folder_id"),
            "indexed_at": entry["indexed_at"],
            "broken": not file_exists,
        }

    for entry in connections_store.list_all_indexed_messages():
        document_id = entry["document_id"]
        if document_id in DOCUMENTS:
            continue
        DOCUMENTS[document_id] = {
            "id": document_id,
            "filename": f"Email {entry['message_id'][:20]}",
            "pages": 0,
            "chunks": 0,
            "path": "",
            "source_type": "email",
            "connection_id": entry["connection_id"],
            "indexed_at": entry["indexed_at"],
        }

    _load_qdrant_orphans()


def _load_qdrant_orphans() -> None:
    """Register vector-only documents so broken entries can be listed and removed."""
    offset = None
    seen: set[str] = set(DOCUMENTS.keys())

    while True:
        results, offset = qdrant.scroll(
            collection_name=COLLECTION_NAME,
            limit=200,
            offset=offset,
            with_payload=True,
        )
        if not results:
            break

        for point in results:
            payload = point.payload or {}
            document_id = payload.get("document_id")
            if not document_id or document_id in seen:
                continue
            seen.add(document_id)
            DOCUMENTS[document_id] = {
                "id": document_id,
                "filename": payload.get("filename", "Unknown"),
                "pages": 0,
                "chunks": 0,
                "path": payload.get("path", ""),
                "source_type": payload.get("source_type", "pdf"),
                "indexed_at": connections_store.get_document_indexed_at(document_id),
                "broken": True,
            }

        if offset is None:
            break


rebuild_documents_registry()


# -------------------------------------------------------------------
# Pydantic models
# -------------------------------------------------------------------

class ChatQuery(BaseModel):
    """
    Request model for asking a question over the indexed document set.

    Attributes:
        question:
            The user question that will be embedded and used for vector search.
        top_k:
            Number of most similar chunks to retrieve from Qdrant before passing
            them to the LLM as context.
    """
    question: str
    top_k: int = 5


class SourceChunk(BaseModel):
    """
    Metadata describing one retrieved source chunk.

    Attributes:
        document_id:
            Internal identifier of the original uploaded document.
        filename:
            Original uploaded file name.
        page:
            PDF page number where the chunk came from.
        text:
            The text snippet used as supporting evidence for the answer.
        score:
            Similarity score returned by Qdrant.
        source_type:
            Origin of the document, e.g. pdf or email.
        file_path:
            Absolute path to the source file on disk, when available.
        folder_path:
            Parent folder containing the source file.
        can_open_folder:
            Whether the client can open the folder in the local file explorer.
    """
    document_id: str
    filename: str
    page: int
    text: str
    score: float
    source_type: str = "pdf"
    file_path: str | None = None
    folder_path: str | None = None
    can_open_folder: bool = False


class FileLocation(BaseModel):
    """A deduplicated file reference the user can open from chat."""
    document_id: str
    filename: str
    source_type: str = "pdf"
    file_path: str | None = None
    folder_path: str | None = None
    can_open_folder: bool = False


class ChatResponse(BaseModel):
    """
    Response model returned by the chat endpoint.

    Attributes:
        answer:
            Final answer generated by DeepSeek using retrieved context.
        sources:
            List of supporting chunks that were used to build the answer.
        file_locations:
            Deduplicated files referenced by the answer, with openable paths.
    """
    answer: str
    sources: List[SourceChunk]
    file_locations: List[FileLocation] = []


class EmailConnectionCreate(BaseModel):
    name: str
    host: str
    port: int = 993
    username: str
    password: str
    folder: str = "INBOX"


class EmailConnectionUpdate(BaseModel):
    name: str | None = None
    host: str | None = None
    port: int | None = None
    username: str | None = None
    password: str | None = None
    folder: str | None = None
    enabled: bool | None = None


class LlmProviderInfo(BaseModel):
    id: str
    name: str
    models: List[str]
    default_model: str
    has_custom_key: bool = False
    api_key_preview: str = ""


class IntelligenceConfigResponse(BaseModel):
    provider: str
    provider_name: str
    model: str
    has_custom_key: bool
    api_key_preview: str
    available_models: List[str]
    available_providers: List[LlmProviderInfo]
    updated_at: str | None = None


class IntelligenceConfigUpdate(BaseModel):
    provider: str
    model: str
    api_key: str | None = None


class LocalModelInfo(BaseModel):
    id: str
    name: str
    description: str
    tier: str
    min_ram_gb: float
    min_disk_gb: float
    download_size_gb: float


class LocalLlmSpecs(BaseModel):
    platform: str
    architecture: str
    cpu_cores: int
    total_ram_gb: float
    available_ram_gb: float
    free_disk_gb: float
    vram_gb: float | None = None
    has_gpu: bool


class LocalLlmCompatibilityResponse(BaseModel):
    compatible: bool
    tier: str
    recommended_model: LocalModelInfo | None = None
    recommendation_reason: str = ""
    blockers: List[str]
    warnings: List[str]
    specs: LocalLlmSpecs
    offered_models: List[LocalModelInfo]
    fitting_models: List[LocalModelInfo]
    managed_by_app: bool = True


class WatchedFolderCreate(BaseModel):
    name: str
    path: str
    recursive: bool = True


class WatchedFolderUpdate(BaseModel):
    name: str | None = None
    recursive: bool | None = None
    enabled: bool | None = None


# -------------------------------------------------------------------
# Utility functions
# -------------------------------------------------------------------

def chunk_text(text: str, chunk_size: int = 1200, overlap: int = 200) -> List[str]:
    """
    Split raw text into overlapping chunks.

    Why this exists:
    Long documents should not be embedded as a single vector because retrieval
    quality becomes poor and token usage increases. Chunking lets the system
    retrieve smaller, more relevant text sections.

    Args:
        text:
            Raw text extracted from a document page.
        chunk_size:
            Target number of characters per chunk.
        overlap:
            Number of trailing characters repeated into the next chunk to avoid
            losing context across boundaries.

    Returns:
        A list of overlapping text chunks. Empty text returns an empty list.

    Notes:
        - This is a simple character-based chunker.
        - Later you may want sentence-aware or heading-aware chunking.
    """
    text = " ".join(text.split())
    if not text:
        return []

    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunks.append(text[start:end])
        if end >= len(text):
            break
        start = end - overlap

    return chunks


def extract_pdf_pages(file_path: Path) -> tuple[int, list[dict]]:
    """
    Extract plain text from each page of a PDF file.

    Args:
        file_path:
            Path to the PDF file on disk.

    Returns:
        A tuple containing:
        - total number of pages
        - a list of dictionaries with keys:
          - 'page': 1-based page index
          - 'text': extracted page text

    Notes:
        - Uses PyMuPDF (`fitz`) for extraction.
        - `page.get_text("text")` is simple and fast.
        - For complex layouts, tables, or OCR-heavy PDFs, this may need
          refinement later.
    """
    doc = fitz.open(file_path)
    pages = []

    for i, page in enumerate(doc):
        text = page.get_text("text")
        pages.append({"page": i + 1, "text": text})

    total_pages = len(doc)
    doc.close()
    return total_pages, pages


def embed_text(text: str) -> list[float]:
    """
    Generate an embedding vector for a text string using a local model.

    Args:
        text:
            Input text to embed.

    Returns:
        A dense float vector compatible with the configured Qdrant collection.

    Notes:
        - Uses FastEmbed (ONNX) for local embeddings (no API key needed).
        - The model runs on the CPU by default.
    """
    return embeddings.embed_text(embedding_model, text)


def find_document_on_disk(document_id: str) -> dict | None:
    """Find a stored PDF by its document ID prefix in the docs folder."""
    matches = sorted(DOCS_DIR.glob(f"{document_id}_*"))
    if matches:
        file_path = matches[0].resolve()
        filename = file_path.name[len(document_id) + 1 :]
        return {
            "id": document_id,
            "filename": filename,
            "pages": 0,
            "chunks": 0,
            "path": str(file_path),
            "source_type": "pdf",
        }

    indexed = connections_store.get_indexed_file_by_document_id(document_id)
    if indexed:
        file_exists = Path(indexed["file_path"]).is_file()
        return {
            "id": document_id,
            "filename": indexed["filename"],
            "pages": 0,
            "chunks": 0,
            "path": indexed["file_path"],
            "source_type": "folder",
            "folder_id": indexed.get("folder_id"),
            "broken": not file_exists,
        }

    indexed_msg = connections_store.get_indexed_message_by_document_id(document_id)
    if indexed_msg:
        return {
            "id": document_id,
            "filename": f"Email {indexed_msg['message_id'][:20]}",
            "pages": 0,
            "chunks": 0,
            "path": "",
            "source_type": "email",
            "connection_id": indexed_msg["connection_id"],
        }
    return None


def resolve_document_metadata(document_id: str) -> dict:
    """Resolve document metadata from memory, disk, or Qdrant payload."""
    doc = DOCUMENTS.get(document_id)
    if doc:
        return doc

    doc = find_document_on_disk(document_id)
    if doc:
        DOCUMENTS[document_id] = doc
        return doc

    results, _ = qdrant.scroll(
        collection_name=COLLECTION_NAME,
        scroll_filter=Filter(
            must=[FieldCondition(key="document_id", match=MatchValue(value=document_id))]
        ),
        limit=1,
        with_payload=True,
    )
    if results:
        payload = results[0].payload or {}
        doc = {
            "id": document_id,
            "filename": payload.get("filename", ""),
            "path": payload.get("path", ""),
            "source_type": payload.get("source_type", "pdf"),
            "subject": payload.get("subject"),
            "pages": 0,
            "chunks": 0,
        }
        resolved_path = resolve_storage_path(doc.get("path"))
        if resolved_path:
            doc["path"] = resolved_path
        elif doc.get("source_type", "pdf") != "email":
            disk_doc = find_document_on_disk(document_id)
            if disk_doc:
                doc.update(disk_doc)
        DOCUMENTS[document_id] = doc
        return doc

    return find_document_on_disk(document_id) or {}


def resolve_storage_path(path: str | None) -> str | None:
    """Return an absolute path for a stored document file."""
    if not path:
        return None
    return str(Path(path).resolve())


def build_source_chunk(hit) -> SourceChunk:
    payload = hit.payload or {}
    document_id = payload.get("document_id", "")
    doc = resolve_document_metadata(document_id)
    raw_path = payload.get("path") or doc.get("path") or ""
    file_path = resolve_storage_path(raw_path)
    source_type = payload.get("source_type") or doc.get("source_type", "pdf")
    folder_path = str(Path(file_path).parent) if file_path else None
    can_open = bool(
        folder_path
        and source_type != "email"
        and Path(folder_path).is_dir()
    )

    return SourceChunk(
        document_id=document_id,
        filename=payload.get("filename", doc.get("filename", "Unknown")),
        page=payload.get("page", 1),
        text=payload.get("text", ""),
        score=hit.score,
        source_type=source_type,
        file_path=file_path,
        folder_path=folder_path,
        can_open_folder=can_open,
    )


def build_file_locations(sources: List[SourceChunk]) -> List[FileLocation]:
    seen: set[str] = set()
    locations: List[FileLocation] = []

    for source in sources:
        if source.document_id in seen:
            continue
        seen.add(source.document_id)
        locations.append(
            FileLocation(
                document_id=source.document_id,
                filename=source.filename,
                source_type=source.source_type,
                file_path=source.file_path,
                folder_path=source.folder_path,
                can_open_folder=source.can_open_folder,
            )
        )
    return locations


def remove_document(document_id: str) -> dict:
    """Remove a document from the search index, including broken/orphan entries."""
    document_id = document_id.strip()
    if not document_id:
        raise HTTPException(status_code=400, detail="Invalid document ID")

    doc = resolve_document_metadata(document_id)
    if not doc:
        indexed = connections_store.get_indexed_file_by_document_id(document_id)
        if indexed:
            doc = {
                "id": document_id,
                "filename": indexed["filename"],
                "source_type": "folder",
                "path": indexed["file_path"],
            }
        else:
            indexed_msg = connections_store.get_indexed_message_by_document_id(document_id)
            if indexed_msg:
                doc = {
                    "id": document_id,
                    "source_type": "email",
                    "path": "",
                }

    try:
        folder_scan.delete_document_vectors(qdrant, COLLECTION_NAME, document_id)
    except Exception as exc:
        print(f"Warning: vector cleanup failed for {document_id}: {exc}")

    connections_store.delete_indexed_file_by_document_id(document_id)
    connections_store.delete_indexed_message_by_document_id(document_id)
    DOCUMENTS.pop(document_id, None)

    source_type = doc.get("source_type", "pdf") if doc else "unknown"
    path = doc.get("path", "") if doc else ""

    deleted_upload_copy = False
    if source_type == "pdf" and path:
        file_path = Path(path).resolve()
        docs_dir = DOCS_DIR.resolve()
        if file_path.is_file() and file_path.parent == docs_dir:
            file_path.unlink(missing_ok=True)
            deleted_upload_copy = True

    return {
        "status": "removed",
        "document_id": document_id,
        "source_type": source_type,
        "original_file_deleted": deleted_upload_copy,
    }


def generate_answer(question: str, context: str) -> str:
    """
    Generate a final answer using the configured LLM provider.

    Args:
        question:
            The original user question.
        context:
            Retrieved supporting context built from top matching document chunks.

    Returns:
        Final answer string produced by the LLM.
    """
    provider_id = settings_store.get_effective_provider()
    provider = llm_providers.get_provider(provider_id)
    api_key = settings_store.get_effective_api_key(provider_id)
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail=f"No API key configured for {provider.name}. Add yours in Intelligence settings.",
        )

    model = settings_store.get_effective_model()
    try:
        return llm_providers.generate_answer(provider_id, model, api_key, question, context)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"{provider.name} request failed: {exc}",
        ) from exc


# -------------------------------------------------------------------
# API routes
# -------------------------------------------------------------------

@app.get("/health")
def health():
    """
    Health check endpoint.

    Returns:
        A simple JSON object indicating whether the API process is alive.

    Why this exists:
        This is useful for local testing, deployment checks, Docker health probes,
        and frontend startup validation.
    """
    return {"status": "ok"}


@app.get("/config/intelligence", response_model=IntelligenceConfigResponse)
def get_intelligence_config():
    """Return current LLM configuration (API key is never returned in full)."""
    return IntelligenceConfigResponse(**settings_store.get_intelligence_settings())


@app.put("/config/intelligence", response_model=IntelligenceConfigResponse)
def update_intelligence_config(payload: IntelligenceConfigUpdate):
    """Update LLM provider settings: provider, model, and API key."""
    try:
        settings = settings_store.update_intelligence_settings(
            provider=payload.provider,
            model=payload.model,
            api_key=payload.api_key,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return IntelligenceConfigResponse(**settings)


@app.get("/local-llm/compatibility", response_model=LocalLlmCompatibilityResponse)
def get_local_llm_compatibility():
    """Scan this PC and recommend a managed on-device chat model."""
    return LocalLlmCompatibilityResponse(**local_llm.check_compatibility())


@app.post("/documents/upload")
async def upload_document(file: UploadFile = File(...)):
    """
    Upload and index a PDF document.

    Workflow:
        1. Validate that the uploaded file is a PDF.
        2. Save the file to local storage.
        3. Extract text page by page.
        4. Chunk the page text.
        5. Generate an embedding for each chunk.
        6. Store all chunk vectors and metadata in Qdrant.
        7. Store high-level document metadata in memory.

    Args:
        file:
            Uploaded PDF file provided as multipart form data.

    Returns:
        Summary metadata about the uploaded document, including page count and
        total number of indexed chunks.

    Raises:
        HTTPException:
            If the uploaded file is not a PDF.

    Notes:
        - This version only supports PDFs.
        - This endpoint performs embedding synchronously, so large files may take time.
        - In production, long indexing jobs should move to a background worker queue.
    """
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported.")

    try:
        document_id = str(uuid.uuid4())
        target_path = (DOCS_DIR / f"{document_id}_{file.filename}").resolve()
        target_path.write_bytes(await file.read())

        pages_count, pages = extract_pdf_pages(target_path)

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
                            "filename": file.filename,
                            "page": page["page"],
                            "text": chunk,
                            "path": str(target_path),
                        },
                    )
                )
                total_chunks += 1

        if points:
            qdrant.upsert(collection_name=COLLECTION_NAME, points=points)

        indexed_at = connections_store._utc_now()
        stat = target_path.stat()
        connections_store.mark_file_indexed(
            str(target_path),
            document_id,
            file.filename,
            stat.st_mtime,
            stat.st_size,
        )

        DOCUMENTS[document_id] = {
            "id": document_id,
            "filename": file.filename,
            "pages": pages_count,
            "chunks": total_chunks,
            "path": str(target_path),
            "source_type": "pdf",
            "indexed_at": indexed_at,
        }
    except Exception as e:
        import traceback
        error_msg = f"{type(e).__name__}: {str(e)}\n{traceback.format_exc()}"
        print(f"Upload error: {error_msg}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

    return {
        "id": document_id,
        "filename": file.filename,
        "pages": pages_count,
        "chunks": total_chunks,
        "source_type": "pdf",
        "indexed_at": indexed_at,
    }


@app.get("/documents")
def list_documents():
    """
    List all uploaded documents known to the application.

    Returns:
        A list of document metadata dictionaries.

    Notes:
        - This data currently comes from an in-memory store.
        - If the server restarts, this registry is lost even though the PDFs
          and Qdrant vectors remain on disk.
        - The next improvement should be persisting this metadata in SQLite.
    """
    return sorted(
        DOCUMENTS.values(),
        key=lambda doc: doc.get("indexed_at") or "",
        reverse=True,
    )


@app.delete("/documents/{document_id}")
def delete_document(document_id: str):
    """Remove a document from the knowledge base.

    Uploaded PDF copies in data/docs are deleted. Folder-scanned and email
    sources are removed from the index only — original files are untouched.
    """
    return remove_document(document_id)


@app.get("/documents/{document_id}/location")
def get_document_location(document_id: str):
    """Return file and folder paths for a document so the client can open them."""
    doc = resolve_document_metadata(document_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    file_path = resolve_storage_path(doc.get("path") or "")
    source_type = doc.get("source_type", "pdf")
    folder_path = str(Path(file_path).parent) if file_path else None
    can_open = bool(
        folder_path
        and source_type != "email"
        and Path(folder_path).is_dir()
    )

    return {
        "document_id": document_id,
        "filename": doc.get("filename", ""),
        "source_type": source_type,
        "file_path": file_path,
        "folder_path": folder_path,
        "can_open_folder": can_open,
    }


@app.get("/documents/{document_id}/download")
def download_document(document_id: str):
    """
    Download the original uploaded PDF file.

    Args:
        document_id:
            Internal identifier assigned during upload.

    Returns:
        A file response serving the original PDF.

    Raises:
        HTTPException:
            If the requested document ID is unknown.

    Notes:
        - This endpoint is intended for source traceability.
        - It allows the frontend to link an answer back to the original document.
    """
    doc = resolve_document_metadata(document_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    if doc.get("source_type") == "email" or not doc.get("path"):
        raise HTTPException(status_code=400, detail="Email documents cannot be downloaded")
    return FileResponse(doc["path"], media_type="application/pdf", filename=doc["filename"])


@app.post("/connections/email")
def create_email_connection(payload: EmailConnectionCreate):
    """Create a new IMAP email connection."""
    connection = connections_store.create_connection(
        name=payload.name,
        host=payload.host,
        port=payload.port,
        username=payload.username,
        password=payload.password,
        folder=payload.folder,
    )
    return connection


@app.get("/connections")
def list_connections():
    """List all configured email connections (passwords omitted)."""
    return connections_store.list_connections()


@app.get("/connections/{connection_id}")
def get_connection(connection_id: str):
    """Get a single email connection by ID."""
    connection = connections_store.get_connection(connection_id)
    if not connection:
        raise HTTPException(status_code=404, detail="Connection not found")
    return connection


@app.put("/connections/{connection_id}")
def update_connection(connection_id: str, payload: EmailConnectionUpdate):
    """Update an existing email connection."""
    connection = connections_store.update_connection(
        connection_id, **payload.model_dump(exclude_unset=True)
    )
    if not connection:
        raise HTTPException(status_code=404, detail="Connection not found")
    return connection


@app.delete("/connections/{connection_id}")
def delete_connection(connection_id: str):
    """Delete an email connection."""
    if not connections_store.delete_connection(connection_id):
        raise HTTPException(status_code=404, detail="Connection not found")
    return {"status": "deleted"}


@app.post("/connections/{connection_id}/sync")
def sync_email_connection(connection_id: str):
    """Fetch recent emails via IMAP and index them into the RAG corpus."""
    connection = connections_store.get_connection(connection_id, include_password=True)
    if not connection:
        raise HTTPException(status_code=404, detail="Connection not found")
    if not connection.get("enabled", True):
        raise HTTPException(status_code=400, detail="Connection is disabled")

    try:
        result = email_sync.index_emails(
            connection,
            chunk_text=chunk_text,
            embed_text=embed_text,
            qdrant=qdrant,
            collection_name=COLLECTION_NAME,
            documents=DOCUMENTS,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return result


@app.post("/connections/{connection_id}/test")
def test_email_connection(connection_id: str):
    """Test IMAP connectivity without indexing."""
    connection = connections_store.get_connection(connection_id, include_password=True)
    if not connection:
        raise HTTPException(status_code=404, detail="Connection not found")

    try:
        email_sync.fetch_emails(
            host=connection["host"],
            port=connection["port"],
            username=connection["username"],
            password=connection["password"],
            folder=connection["folder"],
            limit=1,
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Connection failed: {exc}") from exc

    return {"status": "ok", "message": "Connection successful"}


def _folder_scan_kwargs() -> dict:
    return {
        "chunk_text": chunk_text,
        "embed_text": embed_text,
        "extract_pdf_pages": extract_pdf_pages,
        "qdrant": qdrant,
        "collection_name": COLLECTION_NAME,
        "documents": DOCUMENTS,
    }


@app.post("/folders")
def create_watched_folder(payload: WatchedFolderCreate):
    """Register a folder to scan for PDFs (files stay in place)."""
    path = Path(payload.path).resolve()
    if not path.is_dir():
        raise HTTPException(status_code=400, detail=f"Folder not found: {payload.path}")

    try:
        folder = connections_store.create_watched_folder(
            name=payload.name,
            path=str(path),
            recursive=payload.recursive,
        )
    except Exception as exc:
        if "UNIQUE constraint" in str(exc):
            raise HTTPException(status_code=400, detail="This folder is already being watched") from exc
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return folder


@app.get("/folders")
def list_watched_folders():
    """List all watched folders."""
    return connections_store.list_watched_folders()


@app.get("/folders/{folder_id}")
def get_watched_folder(folder_id: str):
    """Get a single watched folder."""
    folder = connections_store.get_watched_folder(folder_id)
    if not folder:
        raise HTTPException(status_code=404, detail="Folder not found")
    return folder


@app.put("/folders/{folder_id}")
def update_watched_folder(folder_id: str, payload: WatchedFolderUpdate):
    """Update a watched folder."""
    folder = connections_store.update_watched_folder(
        folder_id, **payload.model_dump(exclude_unset=True)
    )
    if not folder:
        raise HTTPException(status_code=404, detail="Folder not found")
    return folder


@app.delete("/folders/{folder_id}")
def delete_watched_folder(folder_id: str):
    """Remove a watched folder (indexed content remains searchable)."""
    if not connections_store.delete_watched_folder(folder_id):
        raise HTTPException(status_code=404, detail="Folder not found")
    return {"status": "deleted"}


@app.post("/folders/{folder_id}/scan")
def scan_watched_folder(folder_id: str):
    """Scan a folder for PDFs and index them without copying files."""
    folder = connections_store.get_watched_folder(folder_id)
    if not folder:
        raise HTTPException(status_code=404, detail="Folder not found")
    if not folder.get("enabled", True):
        raise HTTPException(status_code=400, detail="Folder is disabled")

    try:
        result = folder_scan.scan_folder(folder, **_folder_scan_kwargs())
    except FileNotFoundError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return result


@app.post("/folders/scan-all")
def scan_all_watched_folders():
    """Scan all enabled watched folders."""
    folders = connections_store.list_watched_folders()
    if not folders:
        raise HTTPException(status_code=400, detail="No folders configured")

    result = folder_scan.scan_all_folders(folders, **_folder_scan_kwargs())
    return result


@app.post("/chat/query", response_model=ChatResponse)
def query_documents(payload: ChatQuery):
    """
    Ask a question against the indexed document corpus.

    Workflow:
        1. Embed the user question.
        2. Search Qdrant for the most similar document chunks.
        3. Build a context string from the retrieved chunks.
        4. Send the question plus context to DeepSeek.
        5. Return the answer together with the supporting sources.

    Args:
        payload:
            Request body containing the natural-language question and retrieval depth.

    Returns:
        A structured response containing:
        - the generated answer
        - supporting source chunks with page references

    Notes:
        - This is a standard RAG flow: retrieve first, generate second.
        - The quality of answers depends heavily on chunking strategy, embeddings,
          and prompt design.
        - Adding metadata filters later will let you restrict search by filename,
          document ID, project, date, or department.
    """
    query_vector = embed_text(payload.question)

    results = qdrant.query_points(
        collection_name=COLLECTION_NAME,
        query=query_vector,
        limit=payload.top_k,
        with_payload=True,
    ).points

    sources = [build_source_chunk(hit) for hit in results]
    file_locations = build_file_locations(sources)

    context = "\n\n".join(
        [
            (
                f"[{s.filename} page {s.page}"
                + (f" | File: {s.file_path} | Folder: {s.folder_path}" if s.file_path else "")
                + f"] {s.text}"
            )
            for s in sources
        ]
    )

    answer = generate_answer(payload.question, context)

    return ChatResponse(answer=answer, sources=sources, file_locations=file_locations)