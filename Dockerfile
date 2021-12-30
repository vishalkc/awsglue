FROM amazonlinux:2
LABEL version=1.0 maintainer='Truzent' author='Vishal Chenthamarakshan'
RUN yum update -y && yum install -y procps nano python3 krb5-devel zip shadow-utils lzo wget dnsutils tar vim gcc hostname openssl awscli && yum clean all && rm -rf /var/cache/yum
RUN yes | yum groupinstall "Development Tools"
RUN yes | yum install python3-devel
RUN yum install -y libjpeg-turbo-devel.aarch64 libjpeg-turbo libjpeg-turbo-static.aarch64 zlib-devel.aarch64 zlib-static.aarch64 zlib.aarch64
RUN amazon-linux-extras enable corretto8
RUN yum -y install java-1.8.0-amazon-corretto
RUN amazon-linux-extras enable epel
RUN yum clean metadata && yum -y install epel-release
# COPY /glue-jobs/jre-8u311-linux-x64.tar.gz /usr/lib/jvm/jre.tar.gz
# RUN cd /usr/lib/jvm && tar -xvzf /usr/lib/jvm/jre.tar.gz
# RUN rm -f /usr/lib/jvm/jre.tar.gz
# ENV JAVA_HOME=/usr/lib/jvm

ENV COMMON_PATH=https://aws-glue-jes-prod-us-east-1-assets.s3.amazonaws.com/emr/libs
COPY /glue/awsglue.zip /home/aws-glue-libs/PyGlue.zip
COPY /glue/jarsv1/ /home/aws-glue-libs/jars/
COPY /spark-3.1.1-amzn-0-bin-3.2.1-amzn-31/ /home/spark/
COPY /apache-maven-3.6.0/ /home/apache-maven-3.6.0/
RUN echo "Installing Spark (might take a few mins)" 
RUN cp /home/aws-glue-libs/jars/*.* /home/spark/jars/
RUN wget -q -O /home/spark/jars/hadoop-aws-3.2.0.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.2.0/hadoop-aws-3.2.0.jar
RUN rm  /home/spark/jars/hadoop-aws-3.2.1.jar
    # cd /home/aws-glue-libs && zip -r awsglue.zip awsglue && \
RUN wget -q -O /home/spark/jars/aws-glue-datacatalog-spark-client-1.8.0-SNAPSHOT.jar $COMMON_PATH/aws-glue-datacatalog-spark-client-1.8.0-SNAPSHOT.jar
RUN echo "Installing Spark ends"

RUN echo "Adding spark conf" && \
    cd /home/spark/conf/ && \
    echo "<configuration> <property><name>hive.metastore.connect.retries</name><value>15</value></property><property><name>hive.metastore.client.factory.class</name><value>com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory</value></property></configuration>" > hive-site.xml && \
    echo "export HADOOP_CONF_DIR=/home/spark/conf" > spark-env.sh && \
    echo "<configuration><property><name>fs.s3.impl</name><value>org.apache.hadoop.fs.s3a.S3AFileSystem</value></property><property><name>fs.s3a.impl</name> <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value></property><property><name>fs.s3a.aws.credentials.provider</name> <value>com.amazonaws.auth.DefaultAWSCredentialsProviderChain</value></property><property><name>fs.s3.aws.credentials.provider</name><value>com.amazonaws.auth.DefaultAWSCredentialsProviderChain</value></property></configuration>" > core-site.xml && \
    echo "spark.sql.catalogImplementation hive" > /home/spark/conf/spark-defaults.conf && \
    echo "Adding spark conf ends"

# RUN echo "Installing Zeppelin (might take a few mins)" && \
#   cd /home && wget -q -O /home/zeppelin-0.10.0-bin-all.tgz https://dlcdn.apache.org/zeppelin/zeppelin-0.10.0/zeppelin-0.10.0-bin-all.tgz && \
#   mkdir -p /home/zeppelin/logs /home/zeppelin/run /home/zeppelin/webapps && \
#   tar -xf /home/zeppelin-0.10.0-bin-all.tgz --strip-components=1 -C /home/zeppelin && \
#   rm -f /home/zeppelin-0.10.0-bin-all.tgz && \
#   mv /home/zeppelin/conf/zeppelin-site.xml.template /home/zeppelin/conf/zeppelin-site.xml && \
#   CONTENT="<property><name>zeppelin.interpreters</name><value>org.apache.zeppelin.spark.PySparkInterpreter, org.apache.zeppelin.spark.SparkInterpreter,org.apache.zeppelin.shell.ShellInterpreter</value></property>" && \
#   C=$(echo $CONTENT | sed 's/\//\\\//g') && \
#   sed -i "/<\/configuration>/ s/.*/${C}\n&/" /home/zeppelin/conf/zeppelin-site.xml && \
#   echo "Installing Zeppelin ends"

ENV PYSPARK_PYTHON=python3
ENV SPARK_HOME=/home/spark
ENV ZEPPELIN_ADDR=0.0.0.0
ENV SPARK_CONF_DIR=/home/spark/conf
ENV PYTHONPATH=/home/aws-glue-libs/PyGlue.zip:/home/spark/python/lib/py4j-0.10.9-src.zip:/home/spark/python/
ENV PYSPARK_PYTHON_DRIVER=python3
ENV HADOOP_CONF_DIR=/home/spark/conf
ENV MAVEN_HOME=/home/apache-maven-3.6.0
ENV M2_HOME=/home/apache-maven-3.6.0
ENV PATH=${M2_HOME}/bin:$PATH
# RUN python3 -m pip install --upgrade pip
# RUN echo "Installing python libraries (might take a few mins)" && \
#     pip install python-dotenv pytest pytest-cov awscli boto3 moto[all]
COPY /glue-jobs/spark-branch-3.2/spark/ /home/spark_test/
ENTRYPOINT [ "tail" ]
CMD [ "-f", "/dev/null" ]