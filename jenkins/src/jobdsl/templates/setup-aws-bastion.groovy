job {
  _snip ( 'scm', delegate )
  label ( 'slingshot' )
  steps {
    shell (
"""
#!/bin/bash

cd platform/scripts
bash ./bastion.sh -p \${profile} -r \${region} -P \${full_product} \${action}
"""
    )
  }
}
