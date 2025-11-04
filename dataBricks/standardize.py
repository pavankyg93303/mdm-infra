# Databricks notebook - standardize.py
# Purpose: normalize identifiers, names, dates, currency codes and produce Silver Delta

from pyspark.sql import SparkSession
from pyspark.sql.functions import trim, upper, when, col, to_date, lit, regexp_replace, current_timestamp
from pyspark.sql.types import StringType
import pyspark.sql.functions as F

spark = SparkSession.builder.getOrCreate()

storage_account = dbutils.secrets.get(scope="mdm", key="adls_account")
container = "datalake"
bronze_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/bronze/assets_bronze_delta/"
silver_delta = f"abfss://{container}@{storage_account}.dfs.core.windows.net/silver/assets_standardized/"

# Load data from Bronze
df = spark.read.format("delta").load(bronze_delta)

# Normalization functions
df = df.withColumn("name", trim(col("name")))
df = df.withColumn("name_norm", upper(regexp_replace(col("name"), r"[^A-Z0-9 ]", "")))
df = df.withColumn("isin", upper(regexp_replace(col("isin"), r"[^A-Z0-9]", "")))
df = df.withColumn("cusip", upper(regexp_replace(col("cusip"), r"[^A-Z0-9]", "")))
df = df.withColumn("sedol", upper(regexp_replace(col("sedol"), r"[^A-Z0-9]", "")))
df = df.withColumn("ticker", upper(trim(col("ticker"))))
df = df.withColumn("maturity_date", to_date(col("maturity_date"), "yyyy-MM-dd"))
df = df.withColumn("currency", upper(trim(col("currency"))))

# Add source priority lookup join (example)
# source_priority = spark.read.csv("/datalake/mdm_metadata/source_priorities.csv", header=True)
# df = df.join(source_priority, on='source_system', how='left')

df = df.withColumn("standardized_ts", current_timestamp())

(
    df.write
    .format("delta")
    .mode("append")
    .option("mergeSchema", "true")
    .save(silver_delta)
)

print("Wrote silver delta to:", silver_delta)
