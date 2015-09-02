FROM centos
MAINTAINER Bill Revak william_revak@intuit.com

CMD ["/bin/bash"]

# Install the JDK
RUN yum install -y tar java-1.7.0-openjdk  && rm -rf /var/cache/yum

# Install JMeter
COPY apache-jmeter-2.12 /var/lib/apache-jmeter-2.12

