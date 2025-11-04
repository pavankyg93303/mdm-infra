-- Delta table schemas for MDM (example)
CREATE TABLE IF NOT EXISTS delta.`/datalake/gold/asset_golden` (
  asset_id STRING,
  name STRING,
  legal_name STRING,
  asset_type STRING,
  isin STRING,
  cusip STRING,
  sedol STRING,
  ticker STRING,
  issuer STRING,
  country_of_issue STRING,
  currency STRING,
  maturity_date DATE,
  attributes MAP<STRING,STRING>,
  record_source STRING,
  record_create_ts TIMESTAMP,
  record_update_ts TIMESTAMP,
  record_version LONG,
  match_confidence DOUBLE,
  provenance STRUCT<
    last_sources:ARRAY<STRING>,
    last_match_ts:TIMESTAMP
  >
) USING DELTA
PARTITIONED BY (asset_type);
