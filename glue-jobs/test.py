from pyspark import SparkContext
from awsglue.context import GlueContext

glueContext = GlueContext(SparkContext.getOrCreate())
inputDF = glueContext.create_dynamic_frame_from_options(connection_type="s3", connection_options = {"paths":["s3://awsvishalkc2-glue/customers.json"]}, format="json")
inputDF.toDF().show()