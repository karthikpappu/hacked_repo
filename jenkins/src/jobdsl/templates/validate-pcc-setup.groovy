job {
 	_snip ( 'scm', delegate )
	label('slingshot')
 	steps {
		shell (
"""
#!/bin/bash

cd platform/scripts
sh ./validate_pcc_setup.sh -p \${profile} -r \${region} -y
"""
		)
	}
}
