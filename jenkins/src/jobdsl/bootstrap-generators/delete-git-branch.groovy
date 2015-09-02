job {

	def booleanDesc = """
	when this is checked, the job will only show you info about the branch to be deleted<br>
    <b>UNCHECK THIS FLAG</b> when you are ready to actually delete the branch<br>
	"""

	name ( 'delete-git-branch' )

	logRotator( -1, 100, -1, 100 )

	parameters {
		stringParam ( 'GIT_REPO', 'git@github.intuit.com:cblankenship/automation-testing.git', '' )
		stringParam ( 'GIT_BRANCH_TO_DELETE', '', '' )
        booleanParam ('PREVIEW', true, booleanDesc )
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

export REPO_SUBDIR=\${WORKSPACE}/repo

bash ./branching/delete-git-branch.sh
"""
		)
	}
}



