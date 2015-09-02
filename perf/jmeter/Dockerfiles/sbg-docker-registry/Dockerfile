FROM centos
MAINTAINER Bill Revak william_revak@intuit.com

ENV JDK_VERSION 1.7.0
ENV JMETER_VERSION 2.12

CMD ["/bin/bash"]

# Install the JDK
RUN yum install -y tar java-1.7.0-openjdk  && rm -rf /var/cache/yum

# Install JMeter
COPY apache-jmeter-$JMETER_VERSION /var/lib/

