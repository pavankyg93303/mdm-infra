-- Synapse / Serverless SQL sample to expose Delta gold table (adjust per Synapse version)
-- Option 1: Create an external data source and external table (Parquet/Delta)
CREATE DATABASE IF NOT EXISTS mdm_db;
USE mdm_db;

-- Create database scoped credential if needed; or use managed identity
CREATE EXTERNAL DATA SOURCE adls_mdm
WITH (
  LOCATION = 'abfss://datalake@<STORAGE_ACCOUNT>.dfs.core.windows.net/',
  TYPE = HADOOP
);

-- If serverless cannot directly read Delta, you can create a VIEW using OPENROWSET
CREATE VIEW asset_golden_view AS
SELECT *
FROM
OPENROWSET(
  BULK 'gold/asset_golden',
  DATA_SOURCE = 'adls_mdm',
  FORMAT='DELTA'
) AS rows;
