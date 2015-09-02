job {
  _snip ( 'scm', delegate )
  label ('slingshot')
  steps {
    shell (
"""
#!/bin/bash

cd platform/scripts
bash ./s3_secrets.sh -p \${profile} -r \${region} -P \${full_product} \${action}
"""
    )
  }
}
