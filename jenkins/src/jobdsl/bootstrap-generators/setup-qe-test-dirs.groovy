job {

	name ( 'setup-qe-test-dirs' )

	logRotator( -1, 100, -1, 100 )

	parameters {
		stringParam ( 'APP_NAME', 'automation-testing', '' )
		stringParam ( 'BASE_PACKAGE', "com.intuit.sb.\${APP_NAME}", '' )
		stringParam ( 'GIT_REPO', 'git@github.intuit.com:cblankenship/automation-testing.git', '' )
		booleanParam ( 'OVERWRITE_EXISTING', false, '' )
		stringParam ( 'JDK_VERSION', '1.7', '' )
		stringParam ( 'POM_VERSION', '1.0.0-SNAPSHOT', '' )
		stringParam ( 'RESTASSURED_VERSION', 'v1.1.3', '' )
		choiceParam ( 'COMPONENT_TYPE', ['UI','Service'], '' )
	}

	// CJB!!
	// probably should have a way to automate adding a node to the Jenkins server
	// and give it the label 'slingshot'
	// 
	label ( 'slingshot' )

	scm {
		git {
			remote {
				url ( 'git@gitlab.corp.intuit.net:scm/automation.git' ) // use either url or github				
				// CJB!!
				// These credentials will need to be set up separately (and renamed if not set up the same way)
				// 
				credentials ( 'scmbuild@all-jenkins-slaves' )
			}
			branches ( '*/master' ) // the branches to build, multiple calls are accumulated, defaults to **
			createTag ( true ) // create a tag for every build, optional, defaults to false
			wipeOutWorkspace ( true ) // wipe out workspace and force clone, optional, defaults to false
			relativeTargetDir ( 'automation' )
		}
	}

	wrappers {
		preBuildCleanup ( )
	}

	steps {
		shell (
"""
#!/bin/bash

./automation/testing/setup-restassured.sh
"""
		)
	}

}
