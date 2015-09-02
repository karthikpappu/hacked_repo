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

if [[ "\${DELETE}" == "true" ]]; then
  if [[ -f ~/.ssh/id_rsa.\${profile}-\${region} ]]; then
    rm -f ~/.ssh/id_rsa.\${profile}-\${region}
    rm -f ~/.ssh/id_rsa.\${profile}-\${region}.pub
  fi
  if [[ -f id_rsa.\${profile}-\${region} ]]; then
    rm -f id_rsa.\${profile}-\${region}
    rm -f id_rsa.\${profile}-\${region}.pub
  fi
  aws --profile \${profile} ec2 delete-key-pair --key-name  \${profile}-\${region}
fi

if [[ ! -f ~/.ssh/id_rsa.\${profile}-\${region} ]]; then
  passphrase=\$(echo date | openssl sha1 | cut -d' ' -f2)
  echo \${passphrase} > id_rsa.\${profile}-\${region}-passphrase.txt
  ssh-keygen -t rsa -b 4096 -N "\${passphrase}" -C "\${profile}-\${region}-`date +%F`" -f id_rsa.\${profile}-\${region}
  cp id_rsa.\${profile}-\${region} ~/.ssh/id_rsa.\${profile}-\${region}
  cp id_rsa.\${profile}-\${region}.pub ~/.ssh/id_rsa.\${profile}-\${region}.pub
  echo PASSPHRASE=\${passphrase}
  aws --profile \${profile} ec2 import-key-pair --key-name \${profile}-\${region} --public-key-material=file://./id_rsa.\${profile}-\${region}.pub
else
  echo "[INFO] I found a private key on the slave [~/.ssh/id_rsa.\${profile}-\${region}]"
  echo "[INFO] Let me check if Key Pair is in AWS"
  if [ `aws --profile \${profile} ec2 describe-key-pairs --key-name \${profile}-\${region} > /dev/null 2>&1; echo \$?` -ne 0 ]; then
    aws --profile \${profile} ec2 import-key-pair --key-name \${profile}-\${region} --public-key-material=file://~/.ssh/id_rsa.\${profile}-\${region}.pub
  else
    echo "[INFO] SSH Keys already setup for \${profile}-\${region}"
    echo "[INFO] Rerun with DELETE flag if you want to regenerate it"
    echo "[INFO] Ignore the below warning that there are no id_rsa to archive"
  fi

fi
"""
     )
  }

  publishers {
    archiveArtifacts {
        pattern("id_rsa.*")
        allowEmpty(true)
      }
  }
}
