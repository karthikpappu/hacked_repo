job {

	name ( 'git-update-pom' )

	logRotator( -1, 100, -1, 100 )

	parameters {
		stringParam ( 'GIT_REPO', 'git@github.intuit.com:cblankenship/automation-testing.git', '' )
		stringParam ( 'GIT_TARGET_BRANCH', '', '' )
		stringParam ( 'OLD_VER_STRING', '', '' )
		stringParam ( 'NEW_VER_STRING', '', '' )
		stringParam ( 'OLD_GROUPID_STRING', '', '' )
		stringParam ( 'PRODUCT', '', '' )
		stringParam ( 'COMPONENT', '', '' )
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
		}
	}

	wrappers {
		preBuildCleanup ( )
	}

	steps {
		shell (
"""
#!/bin/sh
rm -rf 
export REPO_SUBDIR=\${WORKSPACE}/repo
export NEW_GROUPID_STRING=com.intuit.sb.\${PRODUCT}.\${COMPONENT}

cd branching
bash ./update-git-pom-ver.sh
bash ./update-git-groupId-ver.sh
"""
		)
	}

}
