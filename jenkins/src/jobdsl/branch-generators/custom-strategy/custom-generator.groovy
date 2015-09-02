job {

	def pipelineTypeList = ['feature', 'develop', 'release']
	def pipelineName = "java_app_\${PIPELINE_TYPE}_workflow"
	def pipelineTypeDesc = """

"""

	name ( "create-${PRODUCT}-${COMPONENT}-custom-pipeline" )

	logRotator( -1, 100, -1, 100 )

	parameters {
        choiceParam ( 'PRODUCT', [ "${PRODUCT}" ], '' )
        choiceParam ( 'COMPONENT', [ "${COMPONENT}" ], '' )
		choiceParam ( 'COMPONENT_TYPE', ["${COMPONENT_TYPE}"], '' )
        choiceParam ( 'PIPELINE_TYPE', pipelineTypeList, '' )
        choiceParam ( 'SOURCE_REPOSITORY', [ "${SOURCE_REPOSITORY}" ], '' )
        stringParam ( 'GIT_SOURCE_BRANCH', '', '' )
        stringParam ( 'GIT_TARGET_BRANCH', '', '' )
		booleanParam ( 'enableSauceConnect', Boolean.valueOf ( "${enableSauceConnect}" ), '' )
		stringParam ( 'sauce_username', "${sauce_username}", '' )
		stringParam ( 'sauce_access_api_key', "${sauce_access_api_key}", '' )
		stringParam ( 'contact_email_or_dl', "${contact_email_or_dl}", '' )
        stringParam ( 'profile', "${profile}"	, '' )
		stringParam ( 'profile_production', "${profile_production}", '' )
	}

    label ( 'slingshot' )

	steps {
		downstreamParameterized {		
			trigger ( 'create-git-branch', 'ALWAYS', false,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {

				predefinedProps ( [ "GIT_REPO" : "\${SOURCE_REPOSITORY}",
									"GIT_SOURCE_BRANCH" : "master",
									"GIT_TARGET_BRANCH" : "\${GIT_TARGET_BRANCH}",
									"BASELINE_NAME" : "baseline-\${GIT_SOURCE_BRANCH}-0001" ] )
			}
		}

		downstreamParameterized {		
			trigger ( 'slingshot-pipeline-generator', 'ALWAYS', false,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {

				predefinedProps ( [ "PRODUCT" : "\${PRODUCT}",
									"COMPONENT" : "\${COMPONENT}",
									"COMPONENT_TYPE" : "\${COMPONENT_TYPE}",
									"PIPELINE" : pipelineName,
									"SOURCE_REPOSITORY" : "\${SOURCE_REPOSITORY}",
									"FULL_BRANCH_PATH" : "\${GIT_TARGET_BRANCH}",
									"enableSauceConnect" : "\${enableSauceConnect}",
									"sauce_username" : "\${sauce_username}",
									"sauce_access_api_key" : "\${sauce_access_api_key}",
									"contact_email_or_dl" : "\${contact_email_or_dl}",
									"profile" : "\${profile}",
									"profile_production" : "\${profile_production}" ] )									
			}
		}
	}
}

