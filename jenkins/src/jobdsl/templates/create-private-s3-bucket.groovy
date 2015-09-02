job {
  _snip ( 'scm', delegate )
  label ('slingshot')
  steps {
    shell (
"""
#!/bin/bash

if [ ! -z "\${accountid}" ]; then
  ARN="-a \${accountid}"
fi
cd platform/scripts
bash ./s3_private.sh -p \${profile} -r \${region} -P \${full_product} \${ARN} \${action}
"""
    )
  }
}
