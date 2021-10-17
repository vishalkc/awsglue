FROM python:3.7.12-buster
LABEL version=1.0 maintainer='CSCS Team' author='Vishal Chenthamarakshan'
ARG CSCS_USER="cscs_glue"
ARG CSCS_UID="1000"
ARG CSCS_GID="100"

ENV GLUE_HOME=/opt/amazon \
	CSCS_USER=$CSCS_USER \
    CSCS_UID=$CSCS_UID \
    CSCS_GID=$CSCS_GID

# ENV LD_LIBRARY_PATH=${GLUE_HOME}/lib/hadoop-lzo-native:${GLUE_HOME}/lib/hadoop-native/:${GLUE_HOME}/lib/glue-native
ENV SPARK_CONF_DIR=/opt/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/conf
ENV ZEPPELIN_PORT 9001
ENV ZEPPELIN_ADDR 0.0.0.0

RUN apt-get update \ 
 && apt-get install -y build-essential libssl-dev libffi-dev python3-pip python3-dev apt-transport-https gnupg ca-certificates

# Use Zscaler certificate
COPY my-root-ca.crt /usr/local/share/ca-certificates
RUN update-ca-certificates	

# JDK 8 installation
RUN wget https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public -O public.key && \
    gpg --no-default-keyring --keyring ./adoptopenjdk-keyring.gpg --import ./public.key && \
	gpg --no-default-keyring --keyring ./adoptopenjdk-keyring.gpg --export --output adoptopenjdk-archive-keyring.gpg && \
	rm public.key && \
	rm adoptopenjdk-keyring.gpg && \
	mv adoptopenjdk-archive-keyring.gpg /usr/share/keyrings && \
	echo "deb [signed-by=/usr/share/keyrings/adoptopenjdk-archive-keyring.gpg] https://adoptopenjdk.jfrog.io/adoptopenjdk/deb buster main" | tee /etc/apt/sources.list.d/adoptopenjdk.list && \
	apt-get update && \
	apt-get install -y adoptopenjdk-8-hotspot

RUN useradd -m -s /bin/bash -N -u $CSCS_UID $CSCS_USER && \
    mkdir -p $GLUE_HOME && \
    chown $CSCS_USER:$CSCS_GID $GLUE_HOME

# Install Spark maven and Zeppelin
RUN curl -SsL https://aws-glue-etl-artifacts.s3.amazonaws.com/glue-common/apache-maven-3.6.0-bin.tar.gz | tar xzf - -C opt/ --warning=no-unknown-keyword
# RUN curl -SsL https://aws-glue-etl-artifacts.s3.amazonaws.com/glue-3.0/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz | tar xzf - -C opt/
COPY spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz opt/
RUN tar -xvf opt/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz -C opt/ \
 	&& rm opt/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3.tgz
RUN curl -SsL https://dlcdn.apache.org/zeppelin/zeppelin-0.10.0/zeppelin-0.10.0.tgz | tar xvzf - -C opt/ --warning=no-unknown-keyword

#Copy AWS Glue libs to opt/amazon/
ADD ./glue3-opt-amazon.tgz opt/amazon/

# Env variables
ENV MAVEN_HOME=/opt/apache-maven-3.6.0
ENV JAVA_HOME=/usr/lib/jvm/adoptopenjdk-8-hotspot-amd64
ENV SPARK_HOME=/opt/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3
ENV PATH=${MAVEN_HOME}/bin:${GLUE_HOME}/bin:$PATH
ENV PYTHONPATH=/opt/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/spark/jars/spark-core_2.12-3.1.1-amzn-0.jar:/opt/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/spark/python/lib/pyspark.zip:/opt/spark-3.1.1-amzn-0-bin-3.2.1-amzn-3/spark/python/lib/py4j-0.10.9-src.zip:${GLUE_HOME}/lib/python3.6/site-packages
ENV PYTHONPATH=/home/aws-glue-libs/awsglue.zip:/home/spark-2.4.3-bin-spark-2.4.3-bin-hadoop2.8/python/lib/pyspark.zip:/home/spark-2.4.3-bin-spark-2.4.3-bin-hadoop2.8/python/lib/py4j-0.10.7-src.zip:/home/spark-2.4.3-bin-spark-2.4.3-bin-hadoop2.8/python

WORKDIR /home
# Install Jupyter notebook
# COPY ./branch-0.6.zip /home/
# COPY ./maven.pem .
# RUN keytool -importcert -file ./maven.pem -keystore $JAVA_HOME/jre/lib/security/cacerts -storepass changeit -noprompt
COPY mavenCert.cer /usr/lib/jvm/adoptopenjdk-8-hotspot-amd64/jre/lib/security
RUN \
    cd $JAVA_HOME/jre/lib/security \
    && keytool -keystore cacerts -storepass changeit -noprompt -trustcacerts -importcert -alias mavencert -file mavenCert.cer
RUN echo "Installing Jupyter" && pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org sparkmagic jupyter && python3 -m pip install ipykernel && python3 -m ipykernel install && jupyter nbextension enable --py --sys-prefix widgetsnbextension && cd /usr/local/lib/python3.7/site-packages && jupyter-kernelspec install sparkmagic/kernels/pysparkkernel && jupyter-kernelspec install sparkmagic/kernels/sparkkernel && jupyter-kernelspec install sparkmagic/kernels/sparkrkernel && jupyter serverextension enable --py sparkmagic && echo "Installing Jupyter ends" 

RUN echo "Installing Livy (might take a few mins)" && cd /home 
RUN wget http://archive.apache.org/dist/incubator/livy/0.6.0-incubating/apache-livy-0.6.0-incubating-src.zip -O /home/livy.zip
RUN unzip -q livy.zip && rm -f /home/livy.zip 
RUN mv apache-livy-0.6.0-incubating livy 
RUN cd /home/livy && mvn -q clean package -DskipTests && mkdir /home/livy/logs  
RUN cp /home/livy/conf/livy.conf.template /home/livy/conf/livy.conf 
RUN sed -i 's|# livy.repl.enable-hive-context =|livy.repl.enable-hive-context = true|g' /home/livy/conf/livy.conf  
RUN echo "Installing Livy ends" 
RUN echo "Setting notebook config" && mkdir /root/.sparkmagic && cd /root/.sparkmagic && echo '{  "kernel_python_credentials" : {    "username": "",    "password": "",    "url": "http://localhost:8998",    "auth": "None"  },  "kernel_scala_credentials" : {    "username": "",    "password": "",    "url": "http://localhost:8998",    "auth": "None"  },  "kernel_r_credentials": {    "username": "",    "password": "",    "url": "http://localhost:8998"  },  "logging_config": {    "version": 1,    "formatters": {      "magicsFormatter": {         "format": "%(asctime)s %(levelname)s %(message)s",        "datefmt": ""      }    },    "handlers": {      "magicsHandler": {         "class": "hdijupyterutils.filehandler.MagicsFileHandler",        "formatter": "magicsFormatter",        "home_path": "~/.sparkmagic"      }    },    "loggers": {      "magicsLogger": {         "handlers": ["magicsHandler"],        "level": "DEBUG",        "propagate": 0      }    }  },  "wait_for_idle_timeout_seconds": 15,  "livy_session_startup_timeout_seconds": 60,  "fatal_error_suggestion": "The code failed because of a fatal error. Some things to try: a) Make sure Spark has enough available resources for Jupyter to create a Spark context. b) Contact your Jupyter administrator to make sure the Spark magics library is configured correctly.   c) Restart the kernel.",  "ignore_ssl_errors": false,  "session_configs": {    "driverMemory": "1000M",    "executorCores": 2  },  "use_auto_viz": true,  "coerce_dataframe": true,  "max_results_sql": 2500,  "pyspark_dataframe_encoding": "utf-8",    "heartbeat_refresh_seconds": 30,  "livy_server_heartbeat_timeout_seconds": 0,  "heartbeat_retry_seconds": 10,  "server_extension_default_kernel_name": "pysparkkernel",  "custom_headers": {},    "retry_policy": "configurable",  "retry_seconds_to_sleep_list": [0.2, 0.5, 1, 3, 5],  "configurable_retry_policy_max_retries": 8}' > config.json && mkdir -p /home/jupyter/jupyter_default_dir && echo "c.NotebookApp.notebook_dir = '/home/jupyter/jupyter_default_dir'" > /root/.jupyter/jupyter_notebook_config.py && echo "#!/bin/bash" >> /home/jupyter/jupyter_start.sh && echo "nohup /home/livy/bin/livy-server &" >> /home/jupyter/jupyter_start.sh && echo "/usr/local/bin/jupyter notebook --allow-root --NotebookApp.token='' --NotebookApp.password='' --no-browser --ip=0.0.0.0" >> /home/jupyter/jupyter_start.sh && chmod 777 /home/jupyter/jupyter_start.sh && echo "Setting notebook config ends"

EXPOSE 8888

# additional python lib/bin
RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org awscli pyspark==3.1.1 pytest boto3 delta-spark==1.0.0
# RUN rm -f ${SPARK_HOME}/bin/pyspark
# RUN ln -s /usr/local/bin/pyspark ${SPARK_HOME}/bin/pyspark

# to run spark in local mode, and enable s3a filesystem instead of EMR
# RUN sed -i 's/spark.master jes/spark.master local/g' /opt/amazon/conf/spark-defaults.conf
# RUN sed -i 's/spark.hadoop.fs.s3.impl com.amazon.ws.emr.hadoop.fs.EmrFileSystem/# spark.hadoop.fs.s3.impl com.amazon.ws.emr.hadoop.fs.EmrFileSystem/g' /opt/amazon/conf/spark-defaults.conf
# RUN sed -i 's/# spark.hadoop.fs.s3.impl org.apache.hadoop.fs.s3a.S3AFileSystem/spark.hadoop.fs.s3.impl org.apache.hadoop.fs.s3a.S3AFileSystem/g' /opt/amazon/conf/spark-defaults.conf

# Apply Spark interpreter config
ADD ./interpreter-0.10.0.json /opt/zeppelin-0.10.0/conf/interpreter.json

# run scripts
RUN echo '#!/usr/bin/env bash \n\n ${SPARK_HOME}/bin/spark-submit --packages io.delta:delta-core_2.12:1.0.0 --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog" $@' > $GLUE_HOME/bin/gluesparksubmit
RUN echo '#!/usr/bin/env bash \n\n ${SPARK_HOME}/bin/pyspark --packages io.delta:delta-core_2.12:1.0.0 --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog" $@' > $GLUE_HOME/bin/gluepyspark
RUN echo '#!/usr/bin/env bash \n\n exec pytest "$@"' > $GLUE_HOME/bin/gluepytest
RUN chmod +x $GLUE_HOME/bin/gluesparksubmit && \
	chmod +x $GLUE_HOME/bin/gluepyspark && \
	chmod +x $GLUE_HOME/bin/gluepytest && \
	mkdir -p /opt/work

# Clean-up some tmp files
# RUN find /opt -name "._*" -type f -delete

WORKDIR $GLUE_HOME
CMD ["/bin/bash"]
# CMD ["/opt/zeppelin-0.10.0/bin/zeppelin.sh"]

