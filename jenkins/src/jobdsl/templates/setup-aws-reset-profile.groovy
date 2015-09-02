job {

 	_snip ( 'scm', delegate )
  label('slingshot')

 	steps {
     shell (
"""
#!/bin/bash

cd platform/scripts
./reset_account.sh -r \${region} -p \${profile} -y
"""
     )
  }

}
