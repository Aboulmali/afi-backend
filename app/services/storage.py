"""Stockage des fichiers : S3 si configuré, sinon disque local (dev/tests)."""
import io
import os
import uuid

from app.config import settings

try:
    import boto3
    from botocore.exceptions import ClientError

    HAS_BOTO3 = True
except ImportError:
    HAS_BOTO3 = False

LOCAL_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "uploads")
os.makedirs(LOCAL_DIR, exist_ok=True)

_client = None


def _s3_client():
    global _client
    if _client is None:
        _client = boto3.client(
            "s3",
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID or None,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY or None,
        )
    return _client


def s3_enabled() -> bool:
    return HAS_BOTO3 and bool(settings.UPLOADS_BUCKET and settings.AWS_ACCESS_KEY_ID)


def upload(data: bytes, content_type: str | None = None) -> tuple[str, str]:
    """Stocke le fichier et renvoie (key, chemin/URI de lecture locale)."""
    key = f"invoices/{uuid.uuid4()}.jpg"

    if s3_enabled():
        try:
            _s3_client().put_object(
                Bucket=settings.UPLOADS_BUCKET,
                Key=key,
                Body=io.BytesIO(data),
                ContentType=content_type or "image/jpeg",
            )
        except ClientError as e:
            raise RuntimeError(f"Upload S3 impossible : {e}") from e
        return key, f"s3://{settings.UPLOADS_BUCKET}/{key}"

    local_path = os.path.join(LOCAL_DIR, key.replace("/", os.sep))
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    with open(local_path, "wb") as f:
        f.write(data)
    return key, local_path


def delete(key: str) -> None:
    """Supprime le fichier stocké (best effort)."""
    if s3_enabled():
        try:
            _s3_client().delete_object(Bucket=settings.UPLOADS_BUCKET, Key=key)
        except ClientError:
            pass
        return
    local_path = os.path.join(LOCAL_DIR, key.replace("/", os.sep))
    if os.path.exists(local_path):
        os.remove(local_path)
