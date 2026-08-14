"""Log SES bounce/complaint/delivery events from SNS for audit and monitoring."""

import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    for record in event.get("Records", []):
        try:
            payload = json.loads(record["Sns"]["Message"])
            event_type = payload.get("eventType") or payload.get("notificationType", "UNKNOWN")
            mail = payload.get("mail", {})
            summary = {
                "event_type": event_type,
                "message_id": mail.get("messageId"),
                "source": mail.get("source"),
                "destination": mail.get("destination"),
            }
            if event_type in ("Bounce", "BOUNCE"):
                summary["bounce"] = payload.get("bounce", {})
            if event_type in ("Complaint", "COMPLAINT"):
                summary["complaint"] = payload.get("complaint", {})
            logger.info("SES event: %s", json.dumps(summary, default=str))
        except Exception:
            logger.exception("Failed to process SNS record: %s", record)
    return {"statusCode": 200}
