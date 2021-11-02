FROM python:3.7.12-buster
LABEL version=1.0 maintainer='Truzent' author='Vishal Chenthamarakshan'

# JDK 1.8 installation
RUN wget https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public -O public.key && \
	gpg --no-default-keyring --keyring ./adoptopenjdk-keyring.gpg --import ./public.key && \
	gpg --no-default-keyring --keyring ./adoptopenjdk-keyring.gpg --export --output adoptopenjdk-archive-keyring.gpg && \
	rm public.key && \
	rm adoptopenjdk-keyring.gpg && \
	mv adoptopenjdk-archive-keyring.gpg /usr/share/keyrings && \
	echo "deb [signed-by=/usr/share/keyrings/adoptopenjdk-archive-keyring.gpg] https://adoptopenjdk.jfrog.io/adoptopenjdk/deb bullseye main" | tee /etc/apt/sources.list.d/adoptopenjdk.list && \
	apt-get update && \
	apt-get install -y adoptopenjdk-8-hotspot zip vim

# Install Spark maven and Zeppelin
RUN wget -q https://aws-glue-etl-artifacts.s3.amazonaws.com/glue-common/apache-maven-3.6.0-bin.tar.gz && tar -C opt/ -xvzf apache-maven-3.6.0-bin.tar.gz && rm -f apache-maven-3.6.0-bin.tar.gz

ENV MAVEN_HOME=/opt/apache-maven-3.6.0
ENV M2_HOME=/opt/apache-maven-3.6.0
ENV PATH=${M2_HOME}/bin:$PATH
ENV SPARK_HOME=/home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3
ENV PYTHONPATH=/home/aws-glue-libs/awsglue.zip:$SPARK_HOME/python/lib/pyspark.zip:$SPARK_HOME/python/lib/py4j-src.zip:$SPARK_HOME/python 
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_PYTHON_DRIVER=python3
ENV ZEPPELIN_ADDR=0.0.0.0
ENV COMMON_PATH=https://aws-glue-jes-prod-us-east-1-assets.s3.amazonaws.com/emr/libs
ENV ZEPPELIN_PORT=8080
# ENV HADOOP_CONF_DIR=/home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/conf
ENV COMMON_PATH=https://aws-glue-jes-prod-us-east-1-assets.s3.amazonaws.com/emr/libs

RUN echo "Installing Glue (might take a few mins)" && cd /home && \
	wget -q https://github.com/awslabs/aws-glue-libs/archive/refs/tags/v3.0.zip && \
	unzip -q v3.0.zip && mv aws-glue-libs-3.0 aws-glue-libs && \
	rm -f v3.0.zip && \
	sed -i 's|</dependencies>|<dependency><groupId>jdk.tools</groupId><artifactId>jdk.tools</artifactId><scope>system</scope><version>1.8</version><systemPath>/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64/lib/tools.jar</systemPath></dependency> </dependencies> <properties><jdk.home>/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64</jdk.home></properties>|g' aws-glue-libs/pom.xml && \
	mvn -q -f aws-glue-libs/pom.xml -DoutputDirectory=jarsv1 dependency:copy-dependencies && cd /home/aws-glue-libs/jarsv1/ && \
	echo "Installing Glue ends"

RUN echo "Installing Spark (might take a few mins)" && \
	cd /home && wget -q https://aws-glue-etl-artifacts.s3.amazonaws.com/glue-3.0/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz && \
	tar -xf spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz && rm -f spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz && \
	cp /home/aws-glue-libs/jarsv1/*.* spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/jars/ && \
	wget -q -O /home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/jars/hadoop-aws-3.2.0.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.2.0/hadoop-aws-3.2.0.jar && \
	rm  /home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/jars/hadoop-aws-3.2.1.jar && \
	cd /home/aws-glue-libs && zip -r awsglue.zip awsglue && \
	wget -q -O /home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/jars/aws-glue-datacatalog-spark-client-1.8.0-SNAPSHOT.jar $COMMON_PATH/aws-glue-datacatalog-spark-client-1.8.0-SNAPSHOT.jar && \
	echo "Installing Spark ends"

RUN echo "Adding spark conf" && \
 	cd /home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/conf/ && \
	echo "<configuration> <property><name>hive.metastore.connect.retries</name><value>15</value></property><property><name>hive.metastore.client.factory.class</name><value>com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory</value></property></configuration>" > hive-site.xml && \
	echo "export HADOOP_CONF_DIR=/home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/conf" > spark-env.sh && \
	echo "<configuration><property><name>fs.s3.impl</name><value>org.apache.hadoop.fs.s3a.S3AFileSystem</value></property><property><name>fs.s3a.impl</name> <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value></property><property><name>fs.s3a.aws.credentials.provider</name> <value>com.amazonaws.auth.DefaultAWSCredentialsProviderChain</value></property><property><name>fs.s3.aws.credentials.provider</name><value>com.amazonaws.auth.DefaultAWSCredentialsProviderChain</value></property></configuration>" > core-site.xml && \
	echo "spark.sql.catalogImplementation hive" > /home/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/conf/spark-defaults.conf && \
	echo "Adding spark conf ends"

RUN echo "Installing Jupyter" && \
	pip install sparkmagic jupyter && \
	python3 -m pip install ipykernel && \
	python3 -m ipykernel install && \
	jupyter nbextension enable --py --sys-prefix widgetsnbextension && \
	cd /usr/local/lib/python3.7/site-packages && \
	jupyter-kernelspec install sparkmagic/kernels/pysparkkernel && \
	jupyter-kernelspec install sparkmagic/kernels/sparkkernel && \
	jupyter-kernelspec install sparkmagic/kernels/sparkrkernel && \
	jupyter serverextension enable --py sparkmagic && \
	echo "Installing Jupyter ends" 

RUN echo "Installing Livy (might take a few mins)" && \
	cd /home && \
	wget -q https://github.com/apache/incubator-livy/archive/refs/heads/master.zip && \
	unzip -q master.zip && \
	rm -f master.zip && \
	mv incubator-livy-master livy && \
	cd /home/livy && \
	mvn -q clean package -DskipTests && \
	mkdir /home/livy/logs && \
	cp /home/livy/conf/livy.conf.template /home/livy/conf/livy.conf && \
	sed -i 's|# livy.repl.enable-hive-context =|livy.repl.enable-hive-context = true|g' /home/livy/conf/livy.conf && \
	echo "Installing Livy ends" 

RUN echo "Setting notebook config" && \
	mkdir /root/.sparkmagic && \
	cd /root/.sparkmagic && \
	echo '{  "kernel_python_credentials" : {    "username": "",    "password": "",    "url": "http://localhost:8998",    "auth": "None"  },  "kernel_scala_credentials" : {    "username": "",    "password": "",    "url": "http://localhost:8998",    "auth": "None"  },  "kernel_r_credentials": {    "username": "",    "password": "",    "url": "http://localhost:8998"  },  "logging_config": {    "version": 1,    "formatters": {      "magicsFormatter": {         "format": "%(asctime)s %(levelname)s %(message)s",        "datefmt": ""      }    },    "handlers": {      "magicsHandler": {         "class": "hdijupyterutils.filehandler.MagicsFileHandler",        "formatter": "magicsFormatter",        "home_path": "~/.sparkmagic"      }    },    "loggers": {      "magicsLogger": {         "handlers": ["magicsHandler"],        "level": "DEBUG",        "propagate": 0      }    }  },  "wait_for_idle_timeout_seconds": 15,  "livy_session_startup_timeout_seconds": 60,  "fatal_error_suggestion": "The code failed because of a fatal error. Some things to try: a) Make sure Spark has enough available resources for Jupyter to create a Spark context. b) Contact your Jupyter administrator to make sure the Spark magics library is configured correctly.   c) Restart the kernel.",  "ignore_ssl_errors": false,  "session_configs": {    "driverMemory": "1000M",    "executorCores": 2  },  "use_auto_viz": true,  "coerce_dataframe": true,  "max_results_sql": 2500,  "pyspark_dataframe_encoding": "utf-8",    "heartbeat_refresh_seconds": 30,  "livy_server_heartbeat_timeout_seconds": 0,  "heartbeat_retry_seconds": 10,  "server_extension_default_kernel_name": "pysparkkernel",  "custom_headers": {},    "retry_policy": "configurable",  "retry_seconds_to_sleep_list": [0.2, 0.5, 1, 3, 5],  "configurable_retry_policy_max_retries": 8}' > config.json && \
	mkdir -p /home/jupyter/jupyter_default_dir && \
	echo "c.NotebookApp.notebook_dir = '/home/jupyter/jupyter_default_dir'" > /root/.jupyter/jupyter_notebook_config.py && \
	echo "#!/bin/bash" >> /home/jupyter/jupyter_start.sh && \
	echo "nohup /home/livy/bin/livy-server &" >> /home/jupyter/jupyter_start.sh && \
	echo "/usr/local/bin/jupyter notebook --allow-root --NotebookApp.token='' --NotebookApp.password='' --no-browser --ip=0.0.0.0" >> /home/jupyter/jupyter_start.sh && \
	chmod 777 /home/jupyter/jupyter_start.sh && \
	echo "Setting notebook config ends"

RUN echo "Installing Zeppelin (might take a few mins)" && \
	cd /home && wget -q -O /home/zeppelin-0.10.0-bin-all.tgz https://dlcdn.apache.org/zeppelin/zeppelin-0.10.0/zeppelin-0.10.0-bin-all.tgz && \
	mkdir -p /home/zeppelin/logs /home/zeppelin/run /home/zeppelin/webapps && \
	tar -xf /home/zeppelin-0.10.0-bin-all.tgz --strip-components=1 -C /home/zeppelin && \
	rm -f /home/zeppelin-0.10.0-bin-all.tgz && \
	echo "Installing Zeppelin ends"

CMD ["/home/zeppelin/bin/zeppelin.sh"]

