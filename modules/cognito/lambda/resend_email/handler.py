"""Cognito Custom Email Sender → Resend (verification + password reset)."""

from __future__ import annotations

import base64
import json
import logging
import os
import urllib.error
import urllib.request

import boto3
from aws_encryption_sdk import CommitmentPolicy, EncryptionSDKClient
from aws_encryption_sdk.key_providers.kms import StrictKmsMasterKeyProvider

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_resend_api_key: str | None = None
_encryption_client: EncryptionSDKClient | None = None
_key_provider: StrictKmsMasterKeyProvider | None = None


def _encryption() -> tuple[EncryptionSDKClient, StrictKmsMasterKeyProvider]:
    global _encryption_client, _key_provider
    if _encryption_client is None:
        _encryption_client = EncryptionSDKClient(
            commitment_policy=CommitmentPolicy.REQUIRE_ENCRYPT_ALLOW_DECRYPT
        )
        _key_provider = StrictKmsMasterKeyProvider(
            key_ids=[os.environ["KMS_KEY_ARN"]]
        )
    return _encryption_client, _key_provider  # type: ignore[return-value]


def _resend_api_key() -> str:
    global _resend_api_key
    if _resend_api_key:
        return _resend_api_key

    sm = boto3.client("secretsmanager")
    raw = sm.get_secret_value(SecretId=os.environ["RESEND_SECRET_ARN"])["SecretString"]
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            _resend_api_key = (
                parsed.get("RESEND_API_KEY")
                or parsed.get("api_key")
                or parsed.get("value")
                or raw
            )
        else:
            _resend_api_key = str(parsed)
    except json.JSONDecodeError:
        _resend_api_key = raw.strip()

    if not _resend_api_key:
        raise RuntimeError("Resend API key missing in secret")
    return _resend_api_key


def _decrypt_code(encrypted_b64: str) -> str:
    client, key_provider = _encryption()
    ciphertext = base64.b64decode(encrypted_b64)
    plaintext, _ = client.decrypt(source=ciphertext, key_provider=key_provider)
    return plaintext.decode("utf-8")


def _email_content(trigger_source: str, code: str) -> tuple[str, str]:
    app = os.environ.get("APP_NAME", "MotorClub")
    site = os.environ.get("APP_URL", "https://motorclub.co.il")

    if trigger_source == "CustomEmailSender_ForgotPassword":
        subject = f"{app} — איפוס סיסמה"
        html = f"""
        <div dir="rtl" style="font-family:Heebo,Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px">
          <h2 style="color:#111;margin:0 0 12px">איפוס סיסמה</h2>
          <p style="color:#444;line-height:1.6">קיבלנו בקשה לאיפוס הסיסמה שלך ב-{app}.</p>
          <p style="font-size:28px;font-weight:bold;letter-spacing:6px;color:#e11d24">{code}</p>
          <p style="color:#666;font-size:14px">הקוד תקף לזמן מוגבל. אם לא ביקשת איפוס — התעלם מהודעה זו.</p>
          <p style="margin-top:24px"><a href="{site}" style="color:#e11d24">{site}</a></p>
        </div>
        """
        return subject, html

    if trigger_source in {
        "CustomEmailSender_SignUp",
        "CustomEmailSender_ResendCode",
        "CustomEmailSender_VerifyUserAttribute",
        "CustomEmailSender_UpdateUserAttribute",
    }:
        subject = f"{app} — קוד אימות"
        html = f"""
        <div dir="rtl" style="font-family:Heebo,Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px">
          <h2 style="color:#111;margin:0 0 12px">ברוכים הבאים ל-{app}</h2>
          <p style="color:#444;line-height:1.6">להשלמת ההרשמה, הזן את הקוד הבא באפליקציה:</p>
          <p style="font-size:28px;font-weight:bold;letter-spacing:6px;color:#e11d24">{code}</p>
          <p style="color:#666;font-size:14px">אם לא נרשמת — התעלם מהודעה זו.</p>
          <p style="margin-top:24px"><a href="{site}" style="color:#e11d24">{site}</a></p>
        </div>
        """
        return subject, html

    subject = f"{app} — קוד"
    html = f"<p dir=\"rtl\">הקוד שלך: <strong>{code}</strong></p>"
    return subject, html


def _send_resend(to_email: str, subject: str, html: str) -> None:
    from_name = os.environ.get("FROM_NAME", "MotorClub")
    from_email = os.environ["FROM_EMAIL"]
    payload = json.dumps(
        {
            "from": f"{from_name} <{from_email}>",
            "to": [to_email],
            "subject": subject,
            "html": html,
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        "https://api.resend.com/emails",
        data=payload,
        headers={
            "Authorization": f"Bearer {_resend_api_key()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode("utf-8")
            logger.info("Resend sent status=%s body=%s", resp.status, body[:200])
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        logger.error("Resend HTTP %s: %s", exc.code, detail)
        raise RuntimeError(f"Resend API error {exc.code}") from exc


def handler(event, context):
    trigger = event.get("triggerSource", "unknown")
    logger.info("Custom email sender trigger=%s", trigger)

    email = event.get("request", {}).get("userAttributes", {}).get("email")
    if not email:
        logger.warning("No email attribute on event")
        return event

    encrypted = event.get("request", {}).get("code")
    if not encrypted:
        logger.warning("No encrypted code on event")
        return event

    code = _decrypt_code(encrypted)
    subject, html = _email_content(trigger, code)
    _send_resend(email, subject, html)
    return event
