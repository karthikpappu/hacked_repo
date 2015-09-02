FROM localhost:5000/jmeter-base:2.12-SBG2
MAINTAINER Bill Revak william_revak@intuit.com

VOLUME [ "/scripts" ]
VOLUME [ "/logs" ]
VOLUME [ "/input-data" ]

EXPOSE 1099 60000

ADD jmeter.properties /var/lib/apache-jmeter-2.12/bin/

ENTRYPOINT [ "/var/lib/apache-jmeter-2.12/bin/jmeter-server" ]
