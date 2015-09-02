job {

	def productDesc = """
<b>choose the name of a product ecosystem to which your app belongs (the job will fail if no product is chosen)</b><br>
<b>possible values are:</b><br>
qbo - QuickBooks Online ecosystem<br>
pcs - Payments ecosystem<br>
icn - Intuit Customer Network ecosystem<br>
ipp - Intuit Partner Platform ecosystem<br>
ems - Employee Management Solutions (Payroll) ecosystem<br>
df  - Demand Force ecosystem<br>
<br>
"""

	def componentDesc = """
<b>enter the name of your app's feature or function within the product ecosystem</b><br>
<b>example values:</b><br>
insights<br>
permissions<br>
cp<br>
payments<br>
dispatcher<br>
<br>
"""

	def componentTypeDesc = """
<b>choose UI if your app has a User Interface</b><br>
<b>choose Service if your app is a background service</b><br>
<br>
<b>if you choose UI</b><br>
+ this job will add testing code and directories designed for automated UI testing in your newly cloned repo<br>
+ your generated pipelines will require manual (i.e. push-button) promotions to QA and E2E environments (this can later be changed to automatic promotion if preferred)<br>
<br>
<b>if you choose Service</b><br>
+ this job will add testing code and directories designed for automated Service app testing in your newly cloned repo (no UI testing code will be added)<br>
+ your generated pipelines will have automatic promotions to QA and E2E environments (this can later be changed to manual promotion if preferred)<br>
<br>
"""

	def enableSauceConnectDesc = """
<b>choose whether or not you will incorporate Sauce Labs tests for your app</b><br>
<br>
<b>if the enableSauceConnect parameter is checked</b><br>
+ your generated pipelines will automatically include Sauce Labs tests during the test phases of each pipeline<br>
<br>
<b>if the enableSauceConnect parameter is not checked</b><br>
+ your generated pipelines will not include any Sauce Labs tests (this can later be changed)<br>
<br>
"""

	def branchingStrategyDesc = """
<b>choose which branching strategy to use for your code base</b><br>
<br>
<b>git-flow branching</b><br>
+ a master branch pipeline and a develop branch pipeline will automatically be created for your code base<br>
+ you can later add (and remove) new feature branch pipelines, new release branch pipelines, and new hotfix branch pipelines<br>
<br>
<b>master-feature branching</b><br>
+ a master branch pipeline pipeline will automatically be created for your code base<br>
+ you can later add (and remove) feature branch pipelines<br>
<br>
<b>custom branching</b><br>
+ you can later add (and remove) new branches and choose what type of pipeline should be generated for each new branch<br>
+ supported pipeline types are feature, develop, and release pipelines<br>
<br>
"""

	def sourceRepoBranchDesc = """
<b>choose which branch to pull from in the source repo</b><br>
<br>
<b>example values</b><br>
master<br>
develop<br>
feature/foo<br>
release/bar<br>
<br>
<b>if the below run_clone_repo parameter is checked</b><br>
+ this job pulls from the specified source branch in the source_repo and (always) pushes that branch to the master branch in the newly cloned repo<br>
+ if git-flow branching is specified, then a develop branch pipeline is also created from the master branch in the newly cloned repo<br>
<br>
<b>if the below run_clone_repo parameter is not checked</b><br>
+ this job pulls from the specified source branch in the source repo and only regenerates a master pipeline using the specified source branch instead of the master branch (this option is for debugging only)<br>
<br>
"""

	def runCloneRepoDesc = """
<b>choose whether or not to create a new repo that is a clone of the source branch on the source repo</b><br>
<br>
<b>if the run_clone_repo parameter is checked</b><br>
+ the source_repo in git will be cloned and named using the above PRODUCT-COMPONENT parameters<br>
+ the cloned repo will always start with a master branch which matches the contents of the source branch in the source repo<br>
+ if git-flow branching is specified, a develop branch will also be created from the master branch in the newly cloned repo<br>
+ the snapshot version in the pom files in the cloned repo will be set to a default setting<br>
+ the QE rest-assured testing directory tree will be generated and added to the newly cloned repo<br>
+ the newly cloned repo is then used for the subsequent onboarding sub jobs<br>
+ this job will fail if a repo of the same name as the cloned repo already exists<br>
<br>
<b>if the run_clone_repo parameter is not checked</b><br>
+ this option should only be used by the slingshot team for debugging purposes<br>
+ no new repo will be cloned from the source repo<br>
+ no changes will be made to the source repo<br>
+ the master branch pipeline (and the develop branch pipeline when git-flow branching is specified) will be regenerated<br>
+ the initial-setup job for AWS will execute<br>
<br>
"""
	def clonedRepoNameDesc = """
<b>DO NOT CHANGE THIS PARAMETER</b><br>
<b>used only by slingshot team for testing and special-cases</b><br>
<br>
"""

	def productChoices = ['', 'qbo','pcs','icn','ipp','ems','df']

	name ( 'onboard-project' )

	logRotator( -1, 100, -1, 100 )

    authorization {
        permission('hudson.model.Item.Workspace:authenticated')
        permission('hudson.model.Item.Read:authenticated')
        permission('hudson.model.Item.Build:authenticated')
        permission('hudson.model.Item.Cancel:authenticated')
    }

	parameters {
		choiceParam ( 'PRODUCT', productChoices, productDesc )
		stringParam ( 'COMPONENT', '', componentDesc )
		choiceParam ( 'COMPONENT_TYPE', ['UI','Service'], componentTypeDesc )
		stringParam ( 'contact_email_or_dl', 'SBG-PD-slingshot-core@intuit.com', '' )
		choiceParam ( 'branching_strategy', ['git-flow', 'master-feature', 'custom'], branchingStrategyDesc )
		booleanParam ( 'enableSauceConnect', false, enableSauceConnectDesc )
		stringParam ( 'sauce_username', '', '' )
		stringParam ( 'sauce_access_api_key', '', '' )
		choiceParam ( 'region', ['us-west-2','us-west-1','us-east-1', 'sa-east-1'], '' )
		stringParam ( 'aws_access_key_id', '', '' )
		stringParam ( 'aws_secret_key_id', '', '' )
		stringParam ( 'profile', '', '' )
		stringParam ( 'profile_production', '', '' )
		stringParam ( 'github_org', 'SBG', '' )
		stringParam ( 'source_repo', 'SBG-TAC/TAC_AWS_Platform', '' )
		stringParam ( 'source_repo_branch', 'master', sourceRepoBranchDesc )
		stringParam ( 'pom_version', '1.1.0-dev-SNAPSHOT', '' )
		booleanParam ( 'run_clone_repo', true, runCloneRepoDesc )
		stringParam ( 'cloned_repo_name', "\${github_org}/\${PRODUCT}-\${COMPONENT}", clonedRepoNameDesc )
	}

	// CJB!!
	// probably should have a way to automate adding a node to the Jenkins server
	// and give it the label 'slingshot'
	//
	label ( 'slingshot' )

	wrappers {
		preBuildCleanup ( )
	}

	steps {
		shell ( """#!/bin/bash
			if [ "\$PRODUCT" = "" ];then
				echo
				echo "[ERROR] a valid PRODUCT value must be selected"
				echo
				exit 1
			fi """ )

		conditionalSteps {
			condition {
				booleanCondition ("\${run_clone_repo}" )
			}
			runner ( 'Run' )

    		downstreamParameterized {
				trigger ( 'clone-github-repo', 'ALWAYS', false,
						[ "buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE" ] ) {

					predefinedProps ( [ "source_repo" : "\${source_repo}",
										"source_repo_branch" : "\${source_repo_branch}",
										"dest_repo" : "\${cloned_repo_name}",
										"dest_repo_branch" : "master" ] )
				}
			}

			downstreamParameterized {
				trigger ( 'git-update-pom', 'ALWAYS', false,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {

					predefinedProps ( [ "GIT_REPO" : "git@github.intuit.com:\${cloned_repo_name}.git",
										"GIT_TARGET_BRANCH" : "master",
										"OLD_VER_STRING" : "1.0.0-dev-SNAPSHOT",
										"OLD_GROUPID_STRING": "com.intuit.sb.devops",
										"NEW_VER_STRING" : "\${pom_version}",
										"PRODUCT" : "\${PRODUCT}",
										"COMPONENT" : "\${COMPONENT}" ] )
				}
			}

			downstreamParameterized {
				trigger ( 'setup-qe-test-dirs', 'ALWAYS', false,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {

					predefinedProps ( [ "APP_NAME" : "\${PRODUCT}-\${COMPONENT}",
										"BASE_PACKAGE" : "com.intuit.sb.\${PRODUCT}.\${COMPONENT}",
										"GIT_REPO" : "git@github.intuit.com:\${cloned_repo_name}.git",
										"OVERWRITE_EXISTING" : false,
										"JDK_VERSION" : "1.7",
										"POM_VERSION" : "\${pom_version}",
										"COMPONENT_TYPE" : "\${COMPONENT_TYPE}" ] )
				}
			}
		}

		downstreamParameterized {
			trigger ( 'create-pipeline-generators', 'ALWAYS', false,
						[ "buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE" ] ) {

				predefinedProps ( [ "SOURCE_REPOSITORY" : "git@github.intuit.com:\${cloned_repo_name}.git",
									"PRODUCT" : "\${PRODUCT}",
									"COMPONENT" : "\${COMPONENT}",
									"COMPONENT_TYPE" : "\${COMPONENT_TYPE}",
									"enableSauceConnect" : "\${enableSauceConnect}",
									"sauce_username" : "\${sauce_username}",
									"sauce_access_api_key" : "\${sauce_access_api_key}",
									"contact_email_or_dl" : "\${contact_email_or_dl}",
									"profile" : "\${profile}",
									"profile_production" : "\${profile_production}",
									"branch" : "master",
									"branching_strategy" : "\${branching_strategy}" ] )
			}
		}

		downstreamParameterized {
			trigger ( "create-\${PRODUCT}-\${COMPONENT}-master-pipeline", 'ALWAYS', true,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] )
		}

		downstreamParameterized {
			trigger ( "enable-disable-jobs-by-regex", 'ALWAYS', true,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {
				predefinedProps ( [ "regularExpression" : "\${PRODUCT}-\${COMPONENT}-master-build-commit",
									"enableJobs" : "false",
									"caseSensitive" : "true" ])
			}
		}

		conditionalSteps {
			condition {
				stringsMatch ( "\${branching_strategy}", 'git-flow', true ) // Run if the two strings match
			}
			runner ( 'Run' )

			downstreamParameterized {
				trigger ( "create-\${PRODUCT}-\${COMPONENT}-develop-pipeline", 'ALWAYS', true,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] )
			}

			downstreamParameterized {
				trigger ( "enable-disable-jobs-by-regex", 'ALWAYS', true,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {
					predefinedProps ( [ "regularExpression" : "\${PRODUCT}-\${COMPONENT}-develop-build-commit",
										"enableJobs" : "false",
										"caseSensitive" : "true" ])
				}
			}
		}

		downstreamParameterized {
			trigger ( "\${PRODUCT}-\${COMPONENT}-master-initial-setup", 'ALWAYS', false,
						[ "buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE" ] ) {

				predefinedProps ( [ "aws_access_key_id" : "\${aws_access_key_id}",
									"aws_secret_key_id" : "\${aws_secret_key_id}",
									"profile" : "\${profile}",
									"profile_production" : "\${profile_production}",
									"operator_email" : "\${contact_email_or_dl}",
									"full_product" : "\${PRODUCT}-\${COMPONENT}",
									"region" : "\${region}" ] )
			}
		}

		downstreamParameterized {
			trigger ( "enable-disable-jobs-by-regex", 'ALWAYS', true,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {
				predefinedProps ( [ "regularExpression" : "\${PRODUCT}-\${COMPONENT}-master-build-commit",
									"enableJobs" : "true",
									"caseSensitive" : "true" ])
			}
		}

		conditionalSteps {
			condition {
				stringsMatch ( "\${branching_strategy}", 'git-flow', true ) // Run if the two strings match
			}
			runner ( 'Run' )

			downstreamParameterized {
				trigger ( "enable-disable-jobs-by-regex", 'ALWAYS', true,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {
					predefinedProps ( [ "regularExpression" : "\${PRODUCT}-\${COMPONENT}-develop-build-commit",
										"enableJobs" : "true",
										"caseSensitive" : "true" ])
				}
			}
		}
	}
}
