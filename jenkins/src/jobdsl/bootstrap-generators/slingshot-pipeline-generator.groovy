job {

	def pipelineBuildDir = 'jenkins/build/jobdsl'

	name ( 'slingshot-pipeline-generator' )

	logRotator( -1, 200, -1, 200 )

	parameters {
		stringParam ( 'PRODUCT', 'slingshot', '' )
		stringParam ( 'COMPONENT', 'test', '' )
		choiceParam ( 'COMPONENT_TYPE', ['UI','Service'], '' )
		stringParam ( 'PIPELINE', 'java_app_master_workflow', '' )
		stringParam ( 'SOURCE_REPOSITORY', 'git@github.intuit.com:SBG-TAC/TAC_AWS_Platform.git', '' )
		stringParam ( 'FULL_BRANCH_PATH', 'master', '' )
		stringParam ( 'JDK', '', '')
		booleanParam ( 'enableSauceConnect', false, '' )
		stringParam ( 'sauce_username', '', '' )
		stringParam ( 'sauce_access_api_key', '', '' )
		stringParam ( 'aws_access_key_id', '', '' )
		stringParam ( 'aws_secret_key_id', '', '' )
		stringParam ( 'profile', '', '' )
		stringParam ( 'profile_production', '', '' )
		stringParam ( 'region', '', '' )
		stringParam ( 'contact_email_or_dl', '', '' )
		stringParam ( 'alternateTestTemplate', '', '' )
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
			branches ( 'origin/${FULL_BRANCH_PATH}' ) // the branches to build, multiple calls are accumulated, defaults to **
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
		// set up the environment variables that will be used for the gradle build
		// of the Jenkins Workflow Engine (aka pipeline generator)
		//
		environmentVariables {
			def gradleEnvVars = [
				"GRADLE_OPTS" : "-Xms768m -Xmx1024m -XX:MaxPermSize=512m",
				"JOBDSL_ROOTDIR" : "\${WORKSPACE}/jenkins/build/jobdsl"
			]
			envs ( gradleEnvVars )
		}

		// step 3
		// run the gradle build to unpack the default Jenkins Workflow Engine
		// code and then overlay the seed repo's Jenkins Workflow Engine code
		// (i.e. dsl templates, snips, helpers, properties, etc. )
		//
        gradle {
	        tasks ( 'clean copyJobDslFiles' )
	        switches ( '--no-daemon --refresh-dependencies' )
            useWrapper ( true )
            description ( 'Assemble the Jenkins Workflow Engine Working directory' )
            rootBuildScriptDir ( '\${WORKSPACE}/jenkins' )
            fromRootBuildScriptDir ( true )
        }

		// step 4
		// run the dsl code through the job dsl plugin to generate the jobs
		// and views
		//
		dsl {
			external ( "${pipelineBuildDir}/jobdsl.groovy" )
			external ( "${pipelineBuildDir}/view-generators/generateViewsByPipeline.groovy" )
			removeAction ( 'IGNORE' )
			ignoreExisting ( false )
		}

		// step 5
		// move any generated jobs that are intended for remote jenkins servers
		// 
		systemGroovyScriptFile ( "${pipelineBuildDir}/moveRemoteJobs.groovy" )

	}

}
