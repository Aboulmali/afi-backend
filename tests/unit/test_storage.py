"""Tests unitaires du service de stockage (mode local, S3 désactivé)."""
import os
import pytest

from app.services import storage


@pytest.fixture(autouse=True)
def _reset_storage(monkeypatch):
    """Force le mode local (pas de bucket configuré) et isole le client."""
    monkeypatch.setattr(storage.settings, "UPLOADS_BUCKET", "")
    monkeypatch.setattr(storage.settings, "AWS_ACCESS_KEY_ID", "")
    storage._client = None
    yield
    storage._client = None


def test_s3_enabled_false_sans_configuration():
    assert storage.s3_enabled() is False


def test_upload_local_et_delete():
    key, path = storage.upload(b"contenu-image", "image/jpeg")
    assert key.startswith("invoices/")
    assert key.endswith(".jpg")
    assert os.path.exists(path)
    with open(path, "rb") as f:
        assert f.read() == b"contenu-image"

    storage.delete(key)
    assert not os.path.exists(path)


def test_upload_local_preserve_donnees():
    key, path = storage.upload(b"abc")
    assert key == path.split("uploads")[-1].replace(os.sep, "/").lstrip("/")
    os.remove(path)


def test_delete_clef_inconnue_est_silencieux():
    storage.delete("invoices/inexistant.jpg")


def test_upload_s3_active(monkeypatch):
    """Avec bucket configuré, upload via boto3 (mocké)."""
    monkeypatch.setattr(storage.settings, "UPLOADS_BUCKET", "afi-uploads-test")
    monkeypatch.setattr(storage.settings, "AWS_ACCESS_KEY_ID", "AKIAX")

    class FakeClient:
        def __init__(self, **kwargs):
            self.put_called = False
            self.delete_called = False

        def put_object(self, **kwargs):
            self.put_called = True
            assert kwargs["Bucket"] == "afi-uploads-test"
            assert kwargs["Key"].startswith("invoices/")
            assert kwargs["Body"].read() == b"data"

        def delete_object(self, **kwargs):
            self.delete_called = True
            assert kwargs["Bucket"] == "afi-uploads-test"

    fake = FakeClient()
    monkeypatch.setattr(storage, "_s3_client", lambda: fake)

    assert storage.s3_enabled() is True
    key, uri = storage.upload(b"data", "image/png")
    assert uri == "s3://afi-uploads-test/" + key
    assert fake.put_called

    storage.delete(key)
    assert fake.delete_called


def test_upload_s3_erreur_clienterror(monkeypatch):
    """Une erreur S3 (ClientError) remonte en RuntimeError."""
    monkeypatch.setattr(storage.settings, "UPLOADS_BUCKET", "afi-uploads-test")
    monkeypatch.setattr(storage.settings, "AWS_ACCESS_KEY_ID", "AKIAX")
    from botocore.exceptions import ClientError

    class FakeClient:
        def put_object(self, **kwargs):
            raise ClientError({"Error": {"Code": "AccessDenied", "Message": "nope"}}, "PutObject")

    monkeypatch.setattr(storage, "_s3_client", lambda: FakeClient())
    with pytest.raises(RuntimeError, match="Upload S3 impossible"):
        storage.upload(b"data")


def test_delete_s3_erreur_silencieuse(monkeypatch):
    """Une erreur S3 à la suppression est silencieuse (best effort)."""
    monkeypatch.setattr(storage.settings, "UPLOADS_BUCKET", "afi-uploads-test")
    monkeypatch.setattr(storage.settings, "AWS_ACCESS_KEY_ID", "AKIAX")
    from botocore.exceptions import ClientError

    class FakeClient:
        def delete_object(self, **kwargs):
            raise ClientError({"Error": {"Code": "AccessDenied", "Message": "nope"}}, "DeleteObject")

    monkeypatch.setattr(storage, "_s3_client", lambda: FakeClient())
    storage.delete("invoices/x.jpg")


def test_s3_client_paresseux_une_seule_fois(monkeypatch):
    """Le client S3 n'est construit qu'une fois (singleton)."""
    monkeypatch.setattr(storage.settings, "UPLOADS_BUCKET", "afi-uploads-test")
    monkeypatch.setattr(storage.settings, "AWS_ACCESS_KEY_ID", "AKIAX")

    import boto3

    original = boto3.client
    calls = []

    def fake_client(*args, **kwargs):
        calls.append(kwargs)
        return object()

    monkeypatch.setattr(boto3, "client", fake_client)
    monkeypatch.setattr(storage, "_client", None)
    try:
        c1 = storage._s3_client()
        c2 = storage._s3_client()
    finally:
        boto3.client = original
    assert c1 is c2
    assert len(calls) == 1
