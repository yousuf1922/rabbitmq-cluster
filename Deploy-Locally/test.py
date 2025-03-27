# filepath: d:\OCodes\rabbitmq-cluster\Deploy-Locally\test.py
import pika

credentials = pika.PlainCredentials('admin', 'securepassword')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', 82, '/', credentials)
)
channel = connection.channel()
channel.queue_declare(queue='test_queue', durable=True)
channel.basic_publish(
    exchange='',
    routing_key='test_queue',
    body='Hello, World!',
    properties=pika.BasicProperties(delivery_mode=2)
)
connection.close()