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

cd platform/scripts
if [[ ! -f JSD-App.jar ]] ; then
  wget -nv http://fmsscm.corp.intuit.net/fms-build/view/TAC/job/CI-devops-JSD-trunk/lastSuccessfulBuild/artifact/JSD-App/target/JSD-App.jar
fi
sh ./egress.sh -p \${profile} -r \${region} create
"""
     )
  }
}
