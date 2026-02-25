#  util/email_service.py
import logging
import os
import smtplib
from email.mime.text import MIMEText

from flask import current_app

# SMTP_SERVER = "smtp-mail.outlook.com"
SMTP_SERVER = "smtp.office365.com"

SMTP_PORT = 587

# Module-level logger (important!)
logger = logging.getLogger(__name__)


def envia_email(to_email: str, subject: str, body: str) -> bool:
    """
    Generic email sending function.
    Returns True if email was sent successfully, False otherwise.
    """

    # smtp_username = current_app.config["OUTLOOK_EMAIL"]
    # smtp_password = current_app.config["OUTLOOK_APP_PASSWORD"]
    #  redis quebou nosso esquema de config
    smtp_username = os.environ.get("OUTLOOK_EMAIL")
    smtp_password = os.environ.get("OUTLOOK_APP_PASSWORD")
    if not smtp_username or not smtp_password:
        logger.error("Worker missing OUTLOOK_EMAIL or OUTLOOK_APP_PASSWORD env vars.")
        return False

    # Build message
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = smtp_username
    msg["To"] = to_email

    try:
        # SMTP context with explicit timeout and safe init
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(smtp_username, smtp_password)
            server.send_message(msg)

        logger.info(f"Email successfully sent to {to_email}")
        return True

    except smtplib.SMTPAuthenticationError:
        logger.error("SMTP authentication failed — check Outlook credentials.")
        return False

    except smtplib.SMTPException as e:
        logger.error(f"SMTP error while sending email to {to_email}: {e}")
        return False

    except Exception as e:
        logger.exception(f"Unexpected error sending email to {to_email}: {e}")
        return False

def task_envia_email(to_email: str, subject: str, body: str) -> bool:
    """
    RQ worker entrypoint. Simple wrapper so workers enqueue this function.
    It's safe because envia_email reads config from environment, not current_app.
    """
    return envia_email(to_email, subject, body)