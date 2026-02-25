import os
import redis
from rq import Queue

from config import EMAIL_QUEUE

# Single global Redis connection
redis_conn = redis.Redis(
    host=os.environ.get("REDIS_HOST", "localhost"),
    port=int(os.environ.get("REDIS_PORT", "6379")),
    db=0,
    password=os.environ.get("REDIS_PASSWORD")  # if needed
)

# Queue name: EMAIL_QUEUE
email_queue = Queue(EMAIL_QUEUE, connection=redis_conn)
