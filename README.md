[![integration-test](https://github.com/gftea/amqprs/actions/workflows/rust.yml/badge.svg)](https://github.com/gftea/amqprs/actions/workflows/rust.yml)

# amqprs

Yet another RabbitMQ client implementation in rust with different design goals.

## Design philosophy

1. API first: easy to use, easy to understand. Keep the API similar as python client library so that it is easier for users to move from there.
2. Minimum external dependencies: as less exteranl crates as possible
3. lock free: no mutex/lock in client library itself 


## Example: Consume and Publish

[Example source code](amqprs/examples/basic_pub_sub.rs) 

```rust
#[tokio::main(flavor = "multi_thread", worker_threads = 2)]
async fn main() {
    // construct a subscriber that prints formatted traces to stdout
    let subscriber = tracing_subscriber::fmt().with_max_level(Level::INFO).finish();

    // use that subscriber to process traces emitted after this point
    tracing::subscriber::set_global_default(subscriber).unwrap();

    //////////////////////////////////////////////////////////////////////////////
    // open a connection to RabbitMQ server
    let args = OpenConnectionArguments::new("localhost:5672", "user", "bitnami");
    let connection = Connection::open(&args).await.unwrap();

    // open a channel on the connection
    let mut channel = connection.open_channel().await.unwrap();

    // declare a queue
    let queue_name = "amqprs";
    channel
        .queue_declare(QueueDeclareArguments::new(queue_name))
        .await
        .unwrap();

    // bind the queue to exchange
    let exchange_name = "amq.topic";
    channel
        .queue_bind(QueueBindArguments::new(
            queue_name,
            exchange_name,
            "eiffel.#",
        ))
        .await
        .unwrap();

    //////////////////////////////////////////////////////////////////////////////
    // start consumer with given name
    let mut args = BasicConsumeArguments::new();
    args.queue = queue_name.to_string();
    args.consumer_tag = "amqprs-consumer-example".to_string();

    channel
        .basic_consume(DefaultConsumer::new(args.no_ack), args)
        .await
        .unwrap();

    //////////////////////////////////////////////////////////////////////////////
    // publish message
    let content = String::from(
        r#"
            {
                "meta": {"id": "f9d42464-fceb-4282-be95-0cd98f4741b0", "type": "PublishTester", "version": "4.0.0", "time": 1640035100149},
                "data": { "customData": []}, 
                "links": [{"type": "BASE", "target": "fa321ff0-faa6-474e-aa1d-45edf8c99896"}]
            }
        "#
        ).into_bytes();

    // create arguments for basic_publish
    let mut args = BasicPublishArguments::new();
    // set target exchange name
    args.exchange = exchange_name.to_string();
    args.routing_key = "eiffel.a.b.c.d".to_string();

    channel
        .basic_publish(BasicProperties::default(), content, args)
        .await
        .unwrap();

    // keep the `channel` and `connection` object from dropping
    // NOTE: channel/connection will be closed when drop
    time::sleep(time::Duration::from_secs(10)).await;
}
```

_Console Output_

```Python console
2022-11-15T13:22:19.207063Z  INFO amqprs::api::consumer: >>>>> Consumer 'amqprs-consumer-example' Start <<<<<
2022-11-15T13:22:19.207127Z  INFO amqprs::api::consumer: Deliver { consumer_tag: ShortStr(23, "amqprs-consumer-example"), delivery_tag: 1, redelivered: false, exchange: ShortStr(9, "amq.topic"), routing_key: ShortStr(14, "eiffel.a.b.c.d") }
2022-11-15T13:22:19.207170Z  INFO amqprs::api::consumer: BasicProperties { property_flags: [0, 0], content_type: None, content_encoding: None, headers: None, delivery_mode: None, priority: None, correlation_id: None, reply_to: None, expiration: None, message_id: None, timestamp: None, typ: None, user_id: None, app_id: None, cluster_id: None }
2022-11-15T13:22:19.207206Z  INFO amqprs::api::consumer: 
            {
                "meta": {"id": "f9d42464-fceb-4282-be95-0cd98f4741b0", "type": "PublishTester", "version": "4.0.0", "time": 1640035100149},
                "data": { "customData": []}, 
                "links": [{"type": "BASE", "target": "fa321ff0-faa6-474e-aa1d-45edf8c99896"}]
            }
        
2022-11-15T13:22:19.207231Z  INFO amqprs::api::consumer: >>>>> Consumer 'amqprs-consumer-example' End <<<<<
```

## Design Architecture
![Lock-free Design](amqp-chosen_design.drawio.png) 