use aws_lambda_events::event::sqs::SqsEvent;
use aws_lambda_events::sqs::{BatchItemFailure, SqsBatchResponse, SqsMessage};
use lambda_runtime::{run, service_fn, tracing, Error, LambdaEvent};

use shared::models::SomeItem;

async fn process_record(record: &SqsMessage) -> Result<(), Error> {
    let record_body = record.body.clone();
    if record_body.is_some() {
        let item: SomeItem = serde_json::from_str(record_body.unwrap().as_str())?;
        // do something with this item
    }
    Ok(())
}

async fn process_records(event: LambdaEvent<SqsEvent>) -> Result<SqsBatchResponse, Error> {
    let mut batch_item_failures = Vec::new();
    for record in event.payload.records {
        match process_record(&record).await {
            Ok(_) => (),
            Err(_) => batch_item_failures.push(BatchItemFailure {
                item_identifier: record.message_id.unwrap(),
            }),
        }
    }

    Ok(SqsBatchResponse {
        batch_item_failures,
    })
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing::init_default_subscriber();

    run(service_fn(process_records)).await
}
