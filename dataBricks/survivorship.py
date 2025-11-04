# Databricks notebook - survivorship.py
# Purpose: apply survivorship rules to candidate groups and produce golden record

from pyspark.sql import SparkSession
from pyspark.sql.functions import row_number, col, current_timestamp
from pyspark.sql.window import Window

spark = SparkSession.builder.getOrCreate()
storage_account = dbutils.secrets.get(scope="mdm", key="adls_account")
container = "datalake"
bronze_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/bronze/assets_bronze_delta/"
silver_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/silver/assets_standardized/"
matching_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/mdm_matches/"
gold_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/gold/asset_golden/"

silver = spark.read.format("delta").load(silver_delta)
matches = spark.read.format("delta").load(matching_delta)

# Build grouping — naive approach: create groups based on transitive closure of matches
# For brevity, assume each candidate pair creates a group id using min(asset_id)
pairs = matches.select(col("left_asset_id").alias("a_id"), col("right_asset_id").alias("b_id"), col("overall_score"))

# Simplified illustration: assign leader per asset by highest source priority or recency
# For each asset choose a preferred record (example: latest ingest_time)
window = Window.partitionBy("asset_id").orderBy(col("ingest_time").desc())
silver_pref = silver.withColumn("rn", row_number().over(window)).where(col("rn")==1).drop("rn")

# If you had groups, you'd aggregate attributes by rule (priority, completeness)
# Example survivorship: for each group pick attribute from preferred source
gold = silver_pref.selectExpr(
    "uuid() as asset_id",
    "name", "legal_name", "asset_type", "isin", "cusip", "sedol", "ticker",
    "issuer", "country_of_issue", "currency", "maturity_date",
    "map() as attributes",
    "record_source", "ingest_time as record_create_ts",
    "ingest_time as record_update_ts",
    "1 as record_version",
    "0.0 as match_confidence"
)

(
    gold.write
    .format("delta")
    .mode("overwrite")
    .option("mergeSchema", "true")
    .save(gold_delta)
)

print("Wrote golden candidates to:", gold_delta)
