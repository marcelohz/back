import sys, os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from app import create_app
from util.rq_queue import email_queue
from util.email_service import task_envia_email

app = create_app()

with app.app_context():
    to = "xxxxxxxxxxxxxxx@gmail.com"
    subject = "Test via Redis Queue"
    body = "This email was sent using Redis + RQ."

    # Enqueue the job
    job = email_queue.enqueue(task_envia_email, to, subject, body)

    print("Queued job!")
    print("Job ID:", job.get_id())
    print("Status right now:", job.get_status())
    print("Waiting for worker...")

# import sys, os
# sys.path.append(os.path.dirname(os.path.dirname(__file__)))
#
# from app import create_app
# import email_service
#
# app = create_app()
#
# with app.app_context():
#     to = "marcelohz@gmail.com"
#     subject = "Test Email"
#     body = "This is a manual test email."
#
#     result = email_service.envia_email(to, subject, body)
#     print("Result:", result)
