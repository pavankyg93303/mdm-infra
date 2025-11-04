# Databricks notebook (PySpark) - ingestion.py
# Purpose: read raw files from ADLS landing, normalize minimal schema, write Bronze Delta table

from pyspark.sql import SparkSession
from pyspark.sql.functions import input_file_name, current_timestamp
import os

spark = SparkSession.builder.getOrCreate()

# Config - replace with widgets/params
storage_account = dbutils.secrets.get(scope="mdm", key="adls_account")
container = "datalake"
raw_path = f"abfss://{container}@{storage_account}.dfs.core.windows.net/bronze/assets_raw/"
bronze_delta_path = f"abfss://{container}@{storage_account}.dfs.core.windows.net/bronze/assets_bronze_delta/"

# Example: read CSVs and JSONs; schema on read
df_csv = spark.read.option("header", True).option("inferSchema", True).csv(raw_path + "sourceA/*/*.csv")
df_json = spark.read.option("multiline", True).json(raw_path + "sourceB/*/*.json")

# Add provenance columns
df_csv = df_csv.withColumn("ingest_time", current_timestamp()).withColumn("source_file", input_file_name())
df_json = df_json.withColumn("ingest_time", current_timestamp()).withColumn("source_file", input_file_name())

# Standardize column names (lowercase)
def lower_cols(df):
    return df.select([df[c].alias(c.lower()) for c in df.columns])

df_csv = lower_cols(df_csv)
df_json = lower_cols(df_json)

# Union and write to Bronze Delta
df_bronze = df_csv.unionByName(df_json, allowMissingColumns=True)

(
    df_bronze.write
    .format("delta")
    .mode("append")
    .option("mergeSchema", "true")
    .save(bronze_delta_path)
)

print("Wrote bronze delta to:", bronze_delta_path)
