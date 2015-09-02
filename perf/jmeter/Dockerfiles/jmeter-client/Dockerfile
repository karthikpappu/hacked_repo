FROM localhost:5000/jmeter-base:2.12-SBG2

MAINTAINER Bill Revak william_revak@intuit.com

# Create mount point for script, data and log files
VOLUME ["/scripts"]
VOLUME ["/input_data"]
VOLUME ["/logs"]

ADD jmeter.properties /var/lib/apache-jmeter-2.12/bin/

ENTRYPOINT [ "/var/lib/apache-jmeter-2.12/bin/jmeter" ]
