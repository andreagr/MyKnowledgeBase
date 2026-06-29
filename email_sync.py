"""IMAP email fetching and indexing into the RAG pipeline."""

import email
import imaplib
import uuid
from email.header import decode_header
from email.utils import parsedate_to_datetime
from typing import Any, Callable

from qdrant_client.models import PointStruct

import connections_store


def _decode_header_value(value: str | None) -> str:
    if not value:
        return ""
    parts = decode_header(value)
    decoded = []
    for part, charset in parts:
        if isinstance(part, bytes):
            decoded.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            decoded.append(part)
    return " ".join(decoded)


def _extract_body(msg: email.message.Message) -> str:
    if msg.is_multipart():
        texts = []
        for part in msg.walk():
            content_type = part.get_content_type()
            disposition = str(part.get("Content-Disposition", ""))
            if "attachment" in disposition:
                continue
            if content_type == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    charset = part.get_content_charset() or "utf-8"
                    texts.append(payload.decode(charset, errors="replace"))
        return "\n".join(texts)

    payload = msg.get_payload(decode=True)
    if not payload:
        return ""
    charset = msg.get_content_charset() or "utf-8"
    return payload.decode(charset, errors="replace")


def fetch_emails(
    host: str,
    port: int,
    username: str,
    password: str,
    folder: str = "INBOX",
    limit: int = 50,
) -> list[dict[str, Any]]:
    mail = imaplib.IMAP4_SSL(host, port)
    try:
        mail.login(username, password)
        status, _ = mail.select(folder, readonly=True)
        if status != "OK":
            raise RuntimeError(f"Cannot open folder: {folder}")

        status, data = mail.search(None, "ALL")
        if status != "OK" or not data[0]:
            return []

        message_nums = data[0].split()
        recent_nums = message_nums[-limit:]

        emails = []
        for num in recent_nums:
            status, msg_data = mail.fetch(num, "(RFC822)")
            if status != "OK" or not msg_data or not msg_data[0]:
                continue

            raw = msg_data[0][1]
            if not isinstance(raw, bytes):
                continue

            msg = email.message_from_bytes(raw)
            message_id = msg.get("Message-ID", f"uid-{num.decode()}")
            subject = _decode_header_value(msg.get("Subject"))
            sender = _decode_header_value(msg.get("From"))
            date_str = msg.get("Date", "")
            try:
                date = parsedate_to_datetime(date_str).isoformat() if date_str else ""
            except (TypeError, ValueError):
                date = date_str

            body = _extract_body(msg)
            emails.append(
                {
                    "message_id": message_id,
                    "subject": subject or "(No subject)",
                    "from": sender,
                    "date": date,
                    "body": body,
                }
            )
        return emails
    finally:
        try:
            mail.logout()
        except Exception:
            pass


def index_emails(
    connection: dict[str, Any],
    *,
    chunk_text: Callable[[str], list[str]],
    embed_text: Callable[[str], list[float]],
    qdrant,
    collection_name: str,
    documents: dict[str, dict],
    limit: int = 50,
) -> dict[str, Any]:
    connection_id = connection["id"]
    try:
        emails = fetch_emails(
            host=connection["host"],
            port=connection["port"],
            username=connection["username"],
            password=connection["password"],
            folder=connection["folder"],
            limit=limit,
        )
    except Exception as exc:
        connections_store.update_sync_status(
            connection_id, "error", f"Connection failed: {exc}"
        )
        raise

    indexed = 0
    skipped = 0

    for mail_item in emails:
        message_id = mail_item["message_id"]
        if connections_store.is_message_indexed(connection_id, message_id):
            skipped += 1
            continue

        subject = mail_item["subject"]
        text = (
            f"Subject: {subject}\n"
            f"From: {mail_item['from']}\n"
            f"Date: {mail_item['date']}\n\n"
            f"{mail_item['body']}"
        )
        chunks = chunk_text(text)
        if not chunks:
            skipped += 1
            continue

        document_id = str(uuid.uuid4())
        points = []
        for chunk in chunks:
            vector = embed_text(chunk)
            points.append(
                PointStruct(
                    id=str(uuid.uuid4()),
                    vector=vector,
                    payload={
                        "document_id": document_id,
                        "filename": f"{subject}.eml",
                        "page": 1,
                        "text": chunk,
                        "path": "",
                        "source_type": "email",
                        "connection_id": connection_id,
                        "message_id": message_id,
                        "subject": subject,
                        "from": mail_item["from"],
                        "date": mail_item["date"],
                    },
                )
            )

        qdrant.upsert(collection_name=collection_name, points=points)
        connections_store.mark_message_indexed(connection_id, message_id, document_id)
        indexed_at = connections_store.get_document_indexed_at(document_id) or connections_store._utc_now()

        documents[document_id] = {
            "id": document_id,
            "filename": f"{subject}.eml",
            "pages": 1,
            "chunks": len(chunks),
            "path": "",
            "source_type": "email",
            "connection_id": connection_id,
            "subject": subject,
            "from": mail_item["from"],
            "date": mail_item["date"],
            "indexed_at": indexed_at,
        }
        indexed += 1

    message = f"Indexed {indexed} new email(s), skipped {skipped} already indexed or empty."
    connections_store.update_sync_status(connection_id, "ok", message, new_messages=indexed)
    return {"indexed": indexed, "skipped": skipped, "message": message}
