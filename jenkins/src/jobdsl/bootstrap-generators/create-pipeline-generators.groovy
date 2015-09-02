job {

	name ( 'create-pipeline-generators' )

	logRotator( -1, 100, -1, 100 )

	parameters {
		stringParam ( 'PRODUCT', '', '' )
		stringParam ( 'COMPONENT', '', '' )
		choiceParam ( 'COMPONENT_TYPE', ['UI','Service'], '' )
		booleanParam ( 'enableSauceConnect', false, '' )
		stringParam ( 'sauce_username', '', '' )
		stringParam ( 'sauce_access_api_key', '', '' )
		stringParam ( 'contact_email_or_dl' , '', '' )
		stringParam ( 'SOURCE_REPOSITORY', '', '' )
		stringParam ( 'profile', '', '' )
		stringParam ( 'profile_production',  '', '' )
		stringParam ( 'branch', 'master', '' )
		choiceParam ( 'branching_strategy', ['git-flow', 'master-feature', 'custom'], '' )
	}

	label ( 'slingshot-master' )

	scm {
		git {
			remote {
				url ( "\${SOURCE_REPOSITORY}" ) // use either url or github
				// CJB!!
				// These credentials will need to be set up separately (and renamed if not set up the same way)
				//
				credentials ( 'scmbuild@all-jenkins-slaves' )
			}
			branches ( "*/\${branch}" ) // the branches to build, multiple calls are accumulated, defaults to **
			wipeOutWorkspace ( true ) // wipe out workspace and force clone, optional, defaults to false
		}
	}

	wrappers {
		preBuildCleanup ( )
	}

	steps {
		dsl {
			external ( "jenkins/src/jobdsl/branch-generators/\${branching_strategy}-strategy/*.groovy" )
			removeAction ( 'IGNORE' )
			ignoreExisting ( false )
		}
	}

}
