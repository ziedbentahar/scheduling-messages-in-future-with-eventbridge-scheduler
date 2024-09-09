use lambda_runtime::{run, service_fn, tracing, Error, LambdaEvent};
use std::env;

use aws_lambda_events::{
    event::dynamodb::Event,
    streams::{DynamoDbBatchItemFailure, DynamoDbEventResponse},
};
use aws_sdk_eventbridge::config::BehaviorVersion;
use aws_sdk_scheduler::types::{
    ActionAfterCompletion, FlexibleTimeWindow, FlexibleTimeWindowMode, Target,
};
use chrono::{Duration, Utc};
use lambda_runtime::tracing::{error, info};
use nanoid::nanoid;
use serde::{Deserialize, Serialize};

use shared::models::SomeItem;

async fn process_records(
    event: LambdaEvent<Event>,
    scheduler_client: &aws_sdk_scheduler::Client,
    scheduler_group_name: &String,
    scheduler_target_arn: &String,
    scheduler_role_arn: &String,
) -> Result<DynamoDbEventResponse, Error> {
    let mut response = DynamoDbEventResponse {
        batch_item_failures: vec![],
    };

    if event.payload.records.is_empty() {
        tracing::info!("No records found. Exiting.");
        return Ok(response);
    }

    for record in &event.payload.records {
        let item = record.change.new_image.clone();
        let new_item: SomeItem = serde_dynamo::from_item(item)?;

        let res = process_new_item(
            &new_item,
            scheduler_client,
            &scheduler_group_name,
            &scheduler_target_arn,
            &scheduler_role_arn,
        )
        .await;

        if res.is_err() {
            let error = res.unwrap_err();
            error!("error processing item - {}", error);
            response.batch_item_failures.push(DynamoDbBatchItemFailure {
                item_identifier: record.change.sequence_number.clone(),
            });
            return Ok(response);
        }
    }

    tracing::info!(
        "Successfully processed {} records",
        event.payload.records.len()
    );

    Ok(response)
}

async fn process_new_item(
    new_item: &SomeItem,
    scheduler_client: &aws_sdk_scheduler::Client,
    scheduler_group_name: &String,
    scheduler_target_arn: &String,
    scheduler_role_arn: &String,
) -> Result<(), Error> {
    info!("creating a new schedule entry for {}", &new_item.id);

    // as an example, we'll configure a one-time schedule two hours after the item was created
    let now = Utc::now();
    let two_hours_later = now + Duration::hours(2);
    let two_hours_later_fmt = two_hours_later.format("%Y-%m-%dT%H:%M:%S").to_string();

    let response = scheduler_client
        .create_schedule()
        .name(format!("schedule-{}", &new_item.id))
        .action_after_completion(ActionAfterCompletion::Delete)
        .target(
            Target::builder()
                .input(serde_json::to_string(&new_item)?)
                .arn(scheduler_target_arn)
                .role_arn(scheduler_role_arn)
                .build()?,
        )
        .flexible_time_window(
            FlexibleTimeWindow::builder()
                .mode(FlexibleTimeWindowMode::Off)
                .build()?,
        )
        .group_name(scheduler_group_name)
        .schedule_expression(format!("at({})", two_hours_later_fmt))
        .client_token(nanoid!())
        .send()
        .await;

    match response {
        Ok(_) => Ok(()),
        Err(e) => {
            // Log the error
            error!("Failed to create schedule: {:?}", e);
            println!("Error: {}", e); // Alternatively, print the error if not using a logger
            return Err(Box::new(e));
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt()
        .json()
        .with_max_level(tracing::Level::INFO)
        .with_current_span(false)
        .with_ansi(false)
        .without_time()
        .with_target(false)
        .init();

    let config = aws_config::load_defaults(BehaviorVersion::latest()).await;

    let scheduler_client = aws_sdk_scheduler::Client::new(&config);

    let scheduler_group_name =
        env::var("SCHEDULER_GROUP_NAME").expect("SCHEDULER_GROUP_NAME not set");

    let scheduler_role_arn = env::var("SCHEDULER_ROLE_ARN").expect("SCHEDULER_ROLE_ARN not set");
    let scheduler_target_arn =
        env::var("SCHEDULER_TARGET_ARN").expect("SCHEDULER_TARGET_ARN not set");

    run(service_fn(|event: LambdaEvent<Event>| async {
        process_records(
            event,
            &scheduler_client,
            &scheduler_group_name,
            &scheduler_target_arn,
            &scheduler_role_arn,
        )
        .await
    }))
    .await
}
