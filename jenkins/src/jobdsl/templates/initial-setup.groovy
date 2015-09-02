job {

    parameters {
		stringParam ( 'aws_access_key_id', "${aws_access_key_id}" )
		stringParam ( 'aws_secret_key_id', "${aws_secret_key_id}" )
		stringParam ( 'git_repo', "${SOURCE_REPOSITORY}" )
		stringParam ( 'operator_email', "${contact_email_or_dl}" )
		booleanParam ( 'DELETE', false )
	}

 	_snip ( 'scm', delegate )
        label('slingshot')

 	steps {

 		shell (
"""
echo "This job kick off others"
"""
 		)
 	}
}
