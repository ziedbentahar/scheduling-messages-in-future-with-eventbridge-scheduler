use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct SomeItem {
    #[serde(rename = "PK")]
    pub id: String,
    #[serde(rename = "Data")]
    pub  data: String,
}
