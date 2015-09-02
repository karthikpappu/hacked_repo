job {
  _snip ( 'scm', delegate )
  label ( 'slingshot' )
  steps {
    shell (
"""
#!/bin/bash

if [[ "\${action}" == "none" ]]; then
  echo 'No action specified. Skipping...'
else
  RDS_OPTIONS="-p \${profile} -r \${region} -P \${full_product} -e \${env} -b \${branch} -t \${type}"
  if [ ! -z "\${prefix}" ]; then
    RDS_OPTIONS="\${RDS_OPTIONS} -x \${prefix}"
  fi
  cd platform/scripts
  bash ./rds.sh \${RDS_OPTIONS} \${action}
fi
"""
    )
  }
}
