job {

	name ( 'slingshot-view-generator' )

	logRotator( -1, 200, -1, 200 )

	parameters {
		stringParam ( 'PRODUCT', 'slingshot', '' )
		stringParam ( 'COMPONENT', 'test', '' )
		stringParam ( 'PIPELINE', 'java_app_master_workflow', '' )
		stringParam ( 'SOURCE_REPOSITORY', 'git@github.intuit.com:SBG-TAC/TAC_AWS_Platform.git', '' )
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
			branches ( 'origin/master' ) // the branches to build, multiple calls are accumulated, defaults to **
			createTag ( true ) // create a tag for every build, optional, defaults to false
			wipeOutWorkspace ( true ) // wipe out workspace and force clone, optional, defaults to false
		}
	}

	wrappers {
		preBuildCleanup ( )
	}

	steps {

		// step 1
		// create file listing all active git branches
		// this will be used by the generateViewsByPipeline.groovy dsl to regenerate
		// the nested views for the active pipelines
		//
		shell (
"""
#!/bin/bash
git branch -r | tee branchlist.txt
"""
			)

		// step 2
		// run the job dsl plugin to generate the views
		//
		dsl {
			external ( 'jenkins/src/jobdsl/view-generators/generateViewsByPipeline.groovy' )
			removeAction ( 'IGNORE' )
			ignoreExisting ( false )
		}

	}

}
