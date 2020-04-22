# author mjaglan@umail.iu.edu
# updated by catherine.verdier@goldenbees.fr
# Coding Style: Shell form

# Start from Ubuntu OS image
FROM ubuntu:18.04

# set root user
USER root

# install utilities on up-to-date node
RUN apt-get update && apt-get -y dist-upgrade && apt-get install -y openssh-server wget scala python

COPY jdk-8u241-linux-x64.tar.gz /jdk.tar.gz
RUN tar xfz jdk.tar.gz \
	&& mv /jdk1.8.0_241 /usr/local/jdk \
	&& rm /jdk.tar.gz

# set java home
ENV JAVA_HOME=/usr/local/jdk

# setup ssh with no passphrase
RUN ssh-keygen -t rsa -f $HOME/.ssh/id_rsa -P "" \
    && cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys \
    && chmod 400 $HOME/.ssh/id_rsa

ENV HADOOP_VERSION=hadoop-3.2.1
#ENV SPARK_VERSION=spark-3.0.0-preview-bin-hadoop3.2
ENV SPARK_VERSION=spark-2.4.5-bin-hadoop2.7

# download & extract & move hadoop & clean up
# TODO: write a way of untarring file to "/usr/local/hadoop" directly
COPY $HADOOP_VERSION".tar.gz" /hadoop.tar.gz
# RUN wget -O /hadoop.tar.gz -q https://iu.box.com/shared/static/u9wy21nev5hxznhuhu0v6dzmcqhkhaz7.gz \
RUN tar xfz hadoop.tar.gz \
	&& mv "/"$HADOOP_VERSION /usr/local/hadoop \
	&& rm /hadoop.tar.gz

# download & extract & move spark & clean up
# TODO: write a way of untarring file to "/usr/local/spark" directly
COPY $SPARK_VERSION".tgz" /spark.tar.gz
#RUN wget -O /spark.tar.gz -q https://iu.box.com/shared/static/avzl4dmlaqs7gsfo9deo11pqfdifu48y.tgz \
RUN tar xfz spark.tar.gz \
	&& mv "/"$SPARK_VERSION /usr/local/spark \
	&& rm /spark.tar.gz

# hadoop environment variables
ENV HADOOP_HOME=/usr/local/hadoop
ENV SPARK_HOME=/usr/local/spark
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$SPARK_HOME:sbin
ENV HDFS_NAMENODE_USER="root"
ENV HDFS_DATANODE_USER="root"
ENV HDFS_SECONDARYNAMENODE_USER="root"
ENV YARN_RESOURCEMANAGER_USER="root"
ENV YARN_NODEMANAGER_USER="root"

# hadoop-store
RUN mkdir -p $HADOOP_HOME/hdfs/namenode \
	&& mkdir -p $HADOOP_HOME/hdfs/datanode

# setup configs - [standalone, pseudo-distributed mode, fully distributed mode]
# NOTE: Directly using COPY/ ADD will NOT work if you are NOT using absolute paths inside the docker image.
# Temporary files: http://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s18.html
COPY config/ /tmp/
RUN mv /tmp/ssh_config $HOME/.ssh/config \
    && chmod 400 $HOME/.ssh/config \
    && mv /tmp/hadoop-env.sh $HADOOP_HOME/etc/hadoop/hadoop-env.sh \
    && mv /tmp/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml \
    && mv /tmp/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml \
    && mv /tmp/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml.template \
    && cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml \
    && mv /tmp/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml \
    && cp /tmp/slaves $HADOOP_HOME/etc/hadoop/workers \
    && mv /tmp/slaves $SPARK_HOME/conf/workers \
    && mv /tmp/spark/spark-env.sh $SPARK_HOME/conf/spark-env.sh \
    && mv /tmp/spark/log4j.properties $SPARK_HOME/conf/log4j.properties

# Add startup script
ADD scripts/spark-services.sh $HADOOP_HOME/spark-services.sh
RUN chmod +x $HADOOP_HOME/spark-services.sh

# set permissions
RUN chmod 744 -R $HADOOP_HOME/etc/hadoop

# format namenode
RUN $HADOOP_HOME/bin/hdfs namenode -format

# run hadoop services
ENTRYPOINT service ssh start; cd $SPARK_HOME; bash

