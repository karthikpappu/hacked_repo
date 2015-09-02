job {

 	_snip ( 'scm', delegate )
    disabled()
    label('slingshot')

    triggers {
        scm ( 'H/5 * * * *' )
    }

 	steps {

 		shell (
"""
#!/bin/bash
export http_proxy=http://\${proxy}:80/
export https_proxy=\${http_proxy}
export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
cd platform/chef-repo
if [ -d ./vendor ] ; then
    rm -rf ./vendor
fi

rm -f ./chef-repo/Berksfile.lock
berks install
berks update
berks vendor ./vendor/cookbooks
#foodcritic -f correctness ./cookbooks
#foodcritic -f correctness ./vendor/cookbooks
/opt/maven/bin/mvn clean install
"""
 		)

 		shell (
 """
#!/bin/bash

cd app
/opt/maven/bin/mvn clean install
"""
 		)

 		shell (
"""
export http_proxy=http://\${proxy}:80/
export https_proxy=\${http_proxy}
export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'

cd platform/cloudformation
for i in *.json ; do echo \${i}; aws --region \${region} --profile=\${profile} cloudformation validate-template --template-body file://./\${i}; done
"""
		)

		shell (
"""
#!/bin/bash
export http_proxy=http://\${proxy}:80/
export https_proxy=\${http_proxy}
export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'

bucket_name=\${profile}-\${region}

aws --profile \${profile} s3 cp ./platform/chef-repo/target/chef-repo.zip s3://\${bucket_name}/\${BUILD_TAG}/chef-repo.zip
aws --profile \${profile} s3 cp ./app/app-assembly/target/app-assembly.zip s3://\${bucket_name}/\${BUILD_TAG}/app-assembly.zip
aws --profile \${profile} s3 cp ./app/app-conf/target/app-conf.zip s3://\${bucket_name}/\${BUILD_TAG}/app-conf.zip
aws --profile \${profile} s3 cp ./app/tomcat/target/dependency/fms-tomcat.zip s3://\${bucket_name}/\${BUILD_TAG}/fms-tomcat.zip
"""
		)
 	}

  _snip ( 'emailNotify', delegate )

}
