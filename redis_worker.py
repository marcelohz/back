# redis_worker.py
import os
import redis
from rq import Queue
from rq.worker import SimpleWorker

from config import EMAIL_QUEUE

redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
conn = redis.Redis.from_url(redis_url)

if __name__ == '__main__':
    queue = Queue(EMAIL_QUEUE, connection=conn)
    worker = SimpleWorker([queue], connection=conn)
    worker.work()

# import os
# import redis
# from rq import Worker, Queue
#
# redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
# conn = redis.Redis.from_url(redis_url)
#
# if __name__ == '__main__':
#     queue = Queue(EMAIL_QUEUE, connection=conn)
#     worker = Worker([queue], connection=conn)
#     worker.work()
