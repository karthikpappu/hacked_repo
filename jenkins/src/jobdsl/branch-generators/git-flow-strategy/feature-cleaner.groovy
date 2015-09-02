job {

	def gitBranchType = 'feature'
	def gitBranchTypeAbbr = 'feat'
	
	def booleanDesc = """
	when this is checked, the job will only show you what jobs will be deleted<br>
    <b>UNCHECK THIS FLAG</b> when you are ready to actually delete the jobs<br>
	"""

	name ( "delete-${PRODUCT}-${COMPONENT}-${gitBranchType}-pipeline" )

	logRotator( -1, 100, -1, 100 )

	parameters {
        choiceParam ( 'PRODUCT', [ "${PRODUCT}" ], '' )
        choiceParam ( 'COMPONENT', [ "${COMPONENT}" ], '' )
        choiceParam ( 'SOURCE_REPOSITORY', [ "${SOURCE_REPOSITORY}" ], '' )
        stringParam ( 'FEATURE_BRANCH', '', '' )
        booleanParam ( 'DELETE_GIT_BRANCH', true, '' )
        booleanParam ( 'PREVIEW', true, booleanDesc )
	}

    label ( 'slingshot' )

	steps {
		conditionalSteps {
		    condition {
		        booleanCondition ( "\${DELETE_GIT_BRANCH}" ) // Run if the token evaluates to true.
		    }
		    runner( 'Run' ) // How to evaluate the results of a failure in the conditional step

			downstreamParameterized {		
				trigger ( 'delete-git-branch', 'ALWAYS', false,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {

					predefinedProps ( [ "GIT_REPO" : "\${SOURCE_REPOSITORY}",
										"GIT_BRANCH_TO_DELETE" : "${gitBranchType}/\${FEATURE_BRANCH}",
										"PREVIEW" : "\${PREVIEW}" ] )

				}
			}
		}

		downstreamParameterized {		
			trigger ( 'delete-jobs-by-regex', 'ALWAYS', false,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {

				predefinedProps ( [ "regularExpression" : "\${PRODUCT}-\${COMPONENT}-${gitBranchTypeAbbr}-\${FEATURE_BRANCH}-.*",
									"preview" : "\${PREVIEW}" ] )									
			}
		}
		
		conditionalSteps {
		    condition {
		    	not {
		      	  booleanCondition ( "\${PREVIEW}" ) // Run if the token evaluates to true.
		      	}
		    }
		    runner( 'Run' ) // How to evaluate the results of a failure in the conditional step

			downstreamParameterized {		
				trigger ( 'slingshot-view-generator', 'ALWAYS', false,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {

					predefinedProps ( [ "PRODUCT" : "\${PRODUCT}",
										"COMPONENT" : "\${COMPONENT}",
										"PIPELINE" : "java_app_${gitBranchType}_workflow",
										"SOURCE_REPOSITORY" : "\${SOURCE_REPOSITORY}" ] )									
				}
			}
		}
	}
}

