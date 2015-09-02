job {
  _snip ( 'scm', delegate )
  label ('slingshot')
  steps {
    shell (
"""
#!/bin/bash

cd platform/scripts
sh ./ingest_default_secrets.sh -p \${profile} -r \${region} -P \${full_product} -R "web,app,admin" -y ingest
"""
    )
  }
}
