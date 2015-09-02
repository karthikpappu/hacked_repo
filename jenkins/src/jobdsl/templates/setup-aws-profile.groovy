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

if ! [ -n "\${aws_access_key_id}" -a -n "\${aws_secret_key_id}" ]; then
   echo aws_access_key_id or aws_secret_access_key can not be null
   exit 2
fi
#if [[ "\${aws_secret_key_id}" == */* ]]; then
#   echo aws_secret_access_key cannot contain "/"
#   exit 3
#fi

if ! grep -q -F "\${profile}" ~/.aws/credentials ; then
cp ~/.aws/credentials{,.backup.`date +%F.%H.%M`}
cat <<EOF>> ~/.aws/credentials

[\${profile}]
output = json
region = \${region}
aws_access_key_id = \${aws_access_key_id}
aws_secret_access_key = \${aws_secret_key_id}
EOF
fi

if ! grep -q -F "\${profile}" ~/.simple_deploy.yml ; then
cp ~/.simple_deploy.yml{,.backup.`date +%F.%H.%M`}
cat <<JSD_EOF>> ~/.simple_deploy.yml
 \${profile}:
    access_key: \${aws_access_key_id}
    secret_key: \${aws_secret_key_id}
    region: \${region}
JSD_EOF
fi

aws --profile \${profile} iam list-access-keys --user-name deploy
"""
     )
  }
}
