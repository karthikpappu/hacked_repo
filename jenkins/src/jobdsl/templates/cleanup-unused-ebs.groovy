job {

 	_snip ( 'scm', delegate )
  label('slingshot')

 	steps {
     shell (
"""
#!/bin/bash

export http_proxy=http://\${proxy}:80/
export https_proxy=\${http_proxy}
export no_proxy='fmsscm.corp.intuit.net,.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
if [[ -n "\$proxy" ]];then
  JAVA_OPTIONS="-Dhttp.proxyHost=\${proxy} -Dhttps.proxyHost=\${proxy} -Dhttp.proxyPort=80 -Dhttps.proxyPort=80"
fi

export AWS_PROFILE=\${profile}
cd platform/scripts
./purge_ebs_volumes.py -r \${region} -t 10

"""
     )
  }

  triggers {
        cron('15 0 * * *')
  }
}
